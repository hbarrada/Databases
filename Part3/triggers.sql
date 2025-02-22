-- Registration handler remains the same
CREATE OR REPLACE FUNCTION handle_registration() RETURNS TRIGGER AS $$
BEGIN
    -- Check if the student exist
    IF NOT EXISTS (SELECT 1 FROM Students WHERE idnr = NEW.student) THEN
        RAISE EXCEPTION 'Student does not exist';
    END IF;

    -- Check if the course exist
    IF NOT EXISTS (SELECT 1 FROM Courses WHERE code = NEW.course) THEN
        RAISE EXCEPTION 'Course does not exist';
    END IF;

    -- Check if already Registered or Waiting
    IF EXISTS (SELECT 1 FROM Registrations WHERE student = NEW.student AND course = NEW.course) THEN
        RAISE EXCEPTION 'Student is already registered or waiting for this course.';
    END IF;

    -- Check if already Passed
    IF EXISTS (SELECT 1 FROM Taken WHERE student = NEW.student AND course = NEW.course AND grade != 'U') THEN
        RAISE EXCEPTION 'Student has already passed this course.';
    END IF;

    -- First check if course is limited and full
    IF EXISTS (SELECT 1 FROM LimitedCourses WHERE code = NEW.course) THEN
        IF (SELECT COUNT(*) FROM Registered WHERE course = NEW.course) >= 
           (SELECT capacity FROM LimitedCourses WHERE code = NEW.course) THEN
            -- Course is full, add to waiting list without checking prerequisites
            INSERT INTO WaitingList (student, course, position)
            VALUES (NEW.student, NEW.course, 
                   (SELECT COALESCE(MAX(position), 0) + 1 
                    FROM WaitingList 
                    WHERE course = NEW.course));
            RETURN NULL;
        END IF;
    END IF;

    -- If we get here, we're going to register the student (either limited course with space or unlimited)
    -- Now we check prerequisites
    IF EXISTS (
        SELECT 1
        FROM Prerequisites p
        WHERE p.course = NEW.course
        AND NOT EXISTS (
            SELECT 1
            FROM Taken t
            WHERE t.student = NEW.student 
            AND t.course = p.prerequisite 
            AND t.grade != 'U'
        )
    ) THEN
        RAISE EXCEPTION 'Prerequisites not met';
    END IF;

    -- If we get here, prerequisites are met, register the student
    INSERT INTO Registered (student, course) 
    VALUES (NEW.student, NEW.course);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Modified unregistration handler with prerequisite checking
CREATE OR REPLACE FUNCTION handle_unregistration() RETURNS TRIGGER AS $$
DECLARE
    first_waiting_student TEXT;
    next_student TEXT;
BEGIN
    -- Was the student registered or waiting?
    IF OLD.status = 'registered' THEN
        -- Student was registered. Delete from Registered table.
        DELETE FROM Registered WHERE student = OLD.student AND course = OLD.course;

        -- Check if the course is limited AND if there are waiters.
        IF EXISTS (SELECT 1 FROM LimitedCourses WHERE code = OLD.course) THEN
            -- Find the first student in the waiting list that meets prerequisites
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
                    AND t.grade != 'U'
                )
            )
            ORDER BY W.position
            LIMIT 1;

            -- If an eligible waiting student was found, register them
            IF first_waiting_student IS NOT NULL THEN
                -- Remove them from waiting list
                DELETE FROM WaitingList 
                WHERE student = first_waiting_student 
                AND course = OLD.course;
                
                -- Register them
                INSERT INTO Registered (student, course) 
                VALUES (first_waiting_student, OLD.course);

                -- Update positions for remaining waiting list students
                UPDATE WaitingList
                SET position = position - 1
                WHERE course = OLD.course
                AND position > (
                    SELECT position 
                    FROM WaitingList 
                    WHERE student = first_waiting_student 
                    AND course = OLD.course
                );
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

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create the triggers
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