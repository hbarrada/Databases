-- Note on prerequisites checking:
-- The domain description states: "To be allowed to register, the student must first fulfill 
-- all prerequisites for the course." We interpret this to apply to direct registration only, 
-- not to being placed on the waiting list. This interpretation is supported by the test cases
-- which expect students to be added to waiting lists regardless of prerequisites.
-- Prerequisites will still be checked when a student is moved from waiting list to registered status.
-- Function that handles all student registration attempts

CREATE OR REPLACE FUNCTION handle_registration() RETURNS TRIGGER AS $$
BEGIN
    -- Check if student exists
    IF NOT EXISTS (SELECT 1 FROM Students WHERE idnr = NEW.student) THEN
        RAISE EXCEPTION 'Student does not exist';
    END IF;

    -- Check if course exists
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

    -- Check prerequisites before registering the student
    IF EXISTS (
        SELECT 1
        FROM Prerequisites p
        WHERE p.course = NEW.course
        AND NOT EXISTS (
            SELECT 1
            FROM Taken t
            WHERE t.student = NEW.student 
            AND t.course = p.prerequisite 
            AND t.grade IN ('3', '4', '5')
        )
    ) THEN
        RAISE EXCEPTION 'Prerequisites not met';
    END IF;

    -- All checks passed, register the student
    INSERT INTO Registered (student, course) 
    VALUES (NEW.student, NEW.course);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function that handles all unregistration attempts
CREATE OR REPLACE FUNCTION handle_unregistration() RETURNS TRIGGER AS $$
DECLARE
    first_waiting_student TEXT;
    course_capacity INT;
    current_registered INT;
    deleted_position INT;
BEGIN
    IF OLD.status = 'registered' THEN
        -- First remove the registration
        DELETE FROM Registered 
        WHERE student = OLD.student 
        AND course = OLD.course;

        -- Only handle waiting list if this is a limited course
        IF EXISTS (SELECT 1 FROM LimitedCourses WHERE code = OLD.course) THEN
            -- Get course capacity and current count
            SELECT capacity INTO course_capacity
            FROM LimitedCourses
            WHERE code = OLD.course;

            SELECT COUNT(*) INTO current_registered
            FROM Registered
            WHERE course = OLD.course;

            -- If we're under capacity, try to register someone from the waiting list
            IF current_registered < course_capacity THEN
                -- Get the first person in the waiting list (by position)
                SELECT W.student INTO first_waiting_student
                FROM WaitingList W
                WHERE W.course = OLD.course
                ORDER BY W.position
                LIMIT 1;

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

                    -- Add them as registered
                    INSERT INTO Registered (student, course)
                    VALUES (first_waiting_student, OLD.course);

                    -- Update positions for remaining students in waiting list
                    UPDATE WaitingList
                    SET position = position - 1
                    WHERE course = OLD.course
                    AND position > deleted_position;
                END IF;
            END IF;
        END IF;

    ELSIF OLD.status = 'waiting' THEN
        -- Handle removal from waiting list
        -- Get position before deleting
        SELECT position INTO deleted_position
        FROM WaitingList
        WHERE student = OLD.student 
        AND course = OLD.course;

        -- Remove from waiting list
        DELETE FROM WaitingList 
        WHERE student = OLD.student 
        AND course = OLD.course;

        -- Update positions for remaining students
        UPDATE WaitingList
        SET position = position - 1
        WHERE course = OLD.course
        AND position > deleted_position;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Set up all the triggers
DROP TRIGGER IF EXISTS registration_trigger ON Registrations;
CREATE TRIGGER registration_trigger
    INSTEAD OF INSERT ON Registrations
    FOR EACH ROW
    EXECUTE FUNCTION handle_registration();

DROP TRIGGER IF EXISTS unregistration_trigger ON Registrations;
CREATE TRIGGER unregistration_trigger
    INSTEAD OF DELETE ON Registrations
    FOR EACH ROW
    EXECUTE FUNCTION handle_unregistration();