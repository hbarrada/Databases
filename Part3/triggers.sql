-- Registration handler
CREATE OR REPLACE FUNCTION handle_registration() RETURNS TRIGGER AS $$
BEGIN
    -- Check if student or course exist
    IF NOT EXISTS (SELECT 1 FROM Students WHERE idnr = NEW.student) THEN
        RAISE EXCEPTION 'Student does not exist';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Courses WHERE code = NEW.course) THEN
        RAISE EXCEPTION 'Course does not exist';
    END IF;

    -- Check if already Registered or Waiting
    IF EXISTS (SELECT 1 FROM Registrations WHERE student = NEW.student AND course = NEW.course) THEN
        RAISE EXCEPTION 'Student is already registered or waiting for this course';
    END IF;

    -- Check if student has already passed the course
    IF EXISTS (SELECT 1 FROM Taken 
               WHERE student = NEW.student 
               AND course = NEW.course 
               AND grade IN ('3', '4', '5')) THEN
        RAISE EXCEPTION 'Student has already passed this course';
    END IF;

    -- Handle limited course registration
    IF EXISTS (SELECT 1 FROM LimitedCourses WHERE code = NEW.course) THEN
        -- Check if course is full
        IF (SELECT COUNT(*) FROM Registered WHERE course = NEW.course) >= 
           (SELECT capacity FROM LimitedCourses WHERE code = NEW.course) THEN
            -- Course is full, add to waiting list without checking prerequisites
            INSERT INTO WaitingList (student, course, position)
            VALUES (NEW.student, NEW.course, 
                   (SELECT COALESCE(MAX(position), 0) + 1 
                    FROM WaitingList 
                    WHERE course = NEW.course));
            RETURN NEW;
        END IF;
    END IF;

    -- Check prerequisites with explicit grade check
    IF EXISTS (
        SELECT 1
        FROM Prerequisites p
        WHERE p.course = NEW.course
        AND NOT EXISTS (
            SELECT 1
            FROM Taken t
            WHERE t.student = NEW.student 
            AND t.course = p.prerequisite 
            AND t.grade IN ('3', '4', '5'))) THEN
        RAISE EXCEPTION 'Prerequisites not met';
    END IF;

    -- All checks passed, register the student
    INSERT INTO Registered (student, course) 
    VALUES (NEW.student, NEW.course);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Unregistration handler with proper capacity check
CREATE OR REPLACE FUNCTION handle_unregistration() RETURNS TRIGGER AS $$
DECLARE
    first_waiting_student TEXT;
    course_capacity INT;
    current_registered INT;
    deleted_position INT;
BEGIN
    IF OLD.status = 'registered' THEN
        -- Student was registered. Delete from Registered table.
        DELETE FROM Registered 
        WHERE student = OLD.student 
        AND course = OLD.course;

        -- Handle waiting list only for limited courses
        IF EXISTS (SELECT 1 FROM LimitedCourses WHERE code = OLD.course) THEN
            -- Get course capacity and current registration count
            SELECT capacity INTO course_capacity
            FROM LimitedCourses
            WHERE code = OLD.course;

            SELECT COUNT(*) INTO current_registered
            FROM Registered
            WHERE course = OLD.course;

            -- Only register new student if we're not still over capacity
            IF current_registered < course_capacity THEN
                -- Get the first person in the waiting list (by position)
                SELECT W.student INTO first_waiting_student
                FROM WaitingList W
                WHERE W.course = OLD.course
                AND NOT EXISTS (
                    SELECT 1
                    FROM Prerequisites p
                    WHERE p.course = OLD.course
                    AND NOT EXISTS (
                        SELECT 1
                        FROM Taken t
                        WHERE t.student = W.student 
                        AND t.course = p.prerequisite 
                        AND t.grade IN ('3', '4', '5')
                    )
                )
                ORDER BY W.position
                LIMIT 1;

                -- If eligible student found, register them
                IF first_waiting_student IS NOT NULL THEN
                    -- Store their position for later updates
                    SELECT position INTO deleted_position
                    FROM WaitingList
                    WHERE student = first_waiting_student 
                    AND course = OLD.course;

                    -- Remove them from waiting list
                    DELETE FROM WaitingList 
                    WHERE student = first_waiting_student 
                    AND course = OLD.course;
                    
                    -- Register them
                    INSERT INTO Registered (student, course) 
                    VALUES (first_waiting_student, OLD.course);

                    -- Update remaining positions
                    UPDATE WaitingList
                    SET position = position - 1
                    WHERE course = OLD.course
                    AND position > deleted_position;
                END IF;
            END IF;
        END IF;

    ELSIF OLD.status = 'waiting' THEN
        -- Student was waiting. Delete from WaitingList table.
        DELETE FROM WaitingList 
        WHERE student = OLD.student 
        AND course = OLD.course;

        -- Update positions for remaining waiting list students
        UPDATE WaitingList
        SET position = position - 1
        WHERE course = OLD.course
        AND position > (
            SELECT position 
            FROM WaitingList 
            WHERE student = OLD.student 
            AND course = OLD.course
        );
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Simple admin registration handler
CREATE OR REPLACE FUNCTION handle_admin_registration() RETURNS TRIGGER AS $$
BEGIN
    -- Check if student exists
    IF NOT EXISTS (SELECT 1 FROM Students WHERE idnr = NEW.student) THEN
        RAISE EXCEPTION 'Student does not exist';
    END IF;

    -- Check if course exists
    IF NOT EXISTS (SELECT 1 FROM Courses WHERE code = NEW.course) THEN
        RAISE EXCEPTION 'Course does not exist';
    END IF;

    -- Check if already registered
    IF EXISTS (SELECT 1 FROM Registered WHERE student = NEW.student AND course = NEW.course) THEN
        RAISE EXCEPTION 'Student is already registered for this course';
    END IF;

    -- If student is in waiting list, remove them
    DELETE FROM WaitingList 
    WHERE student = NEW.student 
    AND course = NEW.course;

    -- Let the registration proceed (admin override)
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create all triggers
DROP TRIGGER IF EXISTS admin_registration_trigger ON Registered;
CREATE TRIGGER admin_registration_trigger
    BEFORE INSERT ON Registered
    FOR EACH ROW
    EXECUTE FUNCTION handle_admin_registration();

DROP TRIGGER IF EXISTS registration_trigger ON Registrations;
CREATE TRIGGER registration_trigger
    INSTEAD OF INSERT ON Registrations
    FOR EACH ROW
    EXECUTE FUNCTION handle_registration();
--*************************************************************
DROP TRIGGER IF EXISTS unregistration_trigger ON Registrations;
CREATE TRIGGER unregistration_trigger
    INSTEAD OF DELETE ON Registrations
    FOR EACH ROW
    EXECUTE FUNCTION handle_unregistration();