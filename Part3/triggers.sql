-- Trigger function for handling course registrations
CREATE OR REPLACE FUNCTION handel_register() RETURNS trigger AS $handel_register$
BEGIN
    

    -- Check if student is already registered or waiting
    IF EXISTS (SELECT 1 FROM Registrations WHERE student = NEW.student AND course = NEW.course)
    OR EXISTS (SELECT 1 FROM WaitingList WHERE student = NEW.student AND course = NEW.course) THEN
    THEN
        RAISE EXCEPTION 'Student is already registered or waiting for this course';
    END IF;

    -- Check if student has already passed the course
    IF EXISTS (SELECT 1 FROM Taken WHERE student = NEW.student AND course = NEW.course AND grade != 'U') THEN
        RAISE EXCEPTION 'Student has already passed this course';
    END IF;

    -- Check prerequisites
    IF EXISTS (SELECT 1 FROM Prerequisites p WHERE pr.course = NEW.course AND 
    NOT EXISTS (SELECT 1 FROM Taken t WHERE t.student = NEW.student AND t.course = pr.prerequisite AND t.grade != 'U')) 
    THEN
        RAISE EXCEPTION 'Prerequisites not met';
    END IF;

    -- Check if course is limited
    IF EXISTS (SELECT 1 FROM LimitedCourses WHERE code = NEW.course) THEN
        -- Check if course is full
        IF (SELECT COUNT(*) >= capacity FROM Registered r JOIN LimitedCourses l ON r.course = l.code 
            WHERE l.code = NEW.course) 
        THEN
            -- Add to waiting list
            INSERT INTO WaitingList VALUES (NEW.student, NEW.course, 
                COALESCE((SELECT MAX(position) + 1 FROM WaitingList WHERE course = NEW.course), 1));
            RETURN NULL;
        END IF;
    END IF;

    -- If we get here, register the student
    INSERT INTO Registered VALUES (NEW.student, NEW.course);
    RETURN NULL;

    -- Check if the student and the course exist
    IF NOT EXISTS (SELECT 1 FROM Students WHERE idnr = NEW.student) THEN
        RAISE EXCEPTION 'Student does not exist';
    END IF;    
    IF NOT EXISTS (SELECT 1 FROM Courses WHERE code = NEW.course) THEN
        RAISE EXCEPTION 'Course does not exist';
    END IF;
END;
$handel_register$ LANGUAGE plpgsql;


-- Trigger function for handling course unregistrations
CREATE OR REPLACE FUNCTION handle_unregister() RETURNS trigger AS $handle_unregister$
DECLARE
    courseCapacity INTEGER;
    currentlyRegistered INTEGER;
    nextStudent TEXT;
BEGIN
    -- If student was registered (not waiting)
    IF EXISTS (SELECT 1 FROM Registered 
               WHERE student = OLD.student AND course = OLD.course) THEN
        -- Remove the registration
        DELETE FROM Registered 
        WHERE student = OLD.student AND course = OLD.course;

        -- Check if this is a limited course
        IF EXISTS (SELECT 1 FROM LimitedCourses WHERE code = OLD.course) THEN
            -- Get course capacity
            SELECT capacity INTO courseCapacity 
            FROM LimitedCourses 
            WHERE code = OLD.course;

            -- Get current number of registered students
            SELECT COUNT(*) INTO currentlyRegistered 
            FROM Registered 
            WHERE course = OLD.course;

            -- If there's room and someone is waiting
            IF currentlyRegistered < courseCapacity THEN
                -- Get first student in waiting list
                SELECT student INTO nextStudent 
                FROM WaitingList 
                WHERE course = OLD.course 
                ORDER BY position LIMIT 1;

                IF FOUND THEN
                    -- Register the student
                    INSERT INTO Registered 
                    VALUES (nextStudent, OLD.course);

                    -- Remove from waiting list
                    DELETE FROM WaitingList 
                    WHERE student = nextStudent AND course = OLD.course;

                    -- Update positions for remaining students
                    UPDATE WaitingList 
                    SET position = position - 1 
                    WHERE course = OLD.course;
                END IF;
            END IF;
        END IF;
    ELSE
        -- If student was waiting, just remove from waiting list
        DELETE FROM WaitingList 
        WHERE student = OLD.student AND course = OLD.course;

        -- Update positions for remaining students
        UPDATE WaitingList 
        SET position = position - 1 
        WHERE course = OLD.course AND position > 
            (SELECT position FROM WaitingList 
             WHERE student = OLD.student AND course = OLD.course);
    END IF;
    RETURN NULL;
END;
$handle_unregister$ LANGUAGE plpgsql;

-- Create the triggers
CREATE TRIGGER register
    INSTEAD OF INSERT ON Registrations
    FOR EACH ROW
    EXECUTE FUNCTION handel_register();

CREATE TRIGGER unregister
    INSTEAD OF DELETE ON Registrations
    FOR EACH ROW
    EXECUTE FUNCTION handle_unregister();