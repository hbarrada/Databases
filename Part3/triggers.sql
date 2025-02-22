-- Function to handle registration logic (used by the trigger)
CREATE OR REPLACE FUNCTION handle_registration() RETURNS TRIGGER AS $$
BEGIN
    -- Check if the student and the course exist
    IF NOT EXISTS (SELECT 1 FROM Students WHERE idnr = NEW.student) THEN
        RAISE EXCEPTION 'Student does not exist';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Courses WHERE code = NEW.course) THEN
        RAISE EXCEPTION 'Course does not exist';
    END IF;

    -- 1. Already Registered or Waiting?
    IF EXISTS (SELECT 1 FROM Registrations WHERE student = NEW.student AND course = NEW.course) THEN
        RAISE EXCEPTION 'Student is already registered or waiting for this course.';
    END IF;

    -- 2. Already Passed?
    IF EXISTS (SELECT 1 FROM Taken WHERE student = NEW.student AND course = NEW.course AND grade <> 'U') THEN
        RAISE EXCEPTION 'Student has already passed this course.';
    END IF;


    -- 3. Check if the course is limited and handle capacity.
    IF EXISTS (SELECT 1 FROM LimitedCourses WHERE code = NEW.course) THEN
        -- Course is limited.  Check if it's full.
        IF (SELECT COUNT(*) FROM Registered WHERE course = NEW.course) >= (SELECT capacity FROM LimitedCourses WHERE code = NEW.course) THEN
            -- Course is full.  Add to waiting list (NO prerequisite check here).
            INSERT INTO WaitingList (student, course, position)
            VALUES (NEW.student, NEW.course, (SELECT COALESCE(MAX(position), 0) + 1 FROM WaitingList WHERE course = NEW.course));
            RETURN NULL; -- Stop the original INSERT.
        ELSE
            -- Course is *not* full.  Now check prerequisites *before* registering.
            IF TG_TABLE_NAME = 'registrations' THEN  -- Only check prerequisites for view inserts
                IF EXISTS (
                    SELECT 1
                    FROM Prerequisites p
                    WHERE p.course = NEW.course
                      AND NOT EXISTS (
                        SELECT 1
                        FROM Taken t
                        WHERE t.student = NEW.student AND t.course = p.prerequisite AND t.grade <> 'U'
                    )
                ) THEN
                    RAISE EXCEPTION 'Student does not meet the prerequisites for this course.';
                END IF;
            END IF;
            -- If we get here, prerequisites are met (or bypassed by admin), register the student.
            INSERT INTO Registered (student, course) VALUES (NEW.student, NEW.course);
            RETURN NULL; -- Stop the original INSERT.

        END IF;
    ELSE
        -- Course is not limited. Check prerequisites *before* registering.
         IF TG_TABLE_NAME = 'registrations' THEN --Only check prerequisites for view inserts.
            IF EXISTS (
                SELECT 1
                FROM Prerequisites p
                WHERE p.course = NEW.course
                  AND NOT EXISTS (
                    SELECT 1
                    FROM Taken t
                    WHERE t.student = NEW.student AND t.course = p.prerequisite AND t.grade <> 'U'
                  )
            ) THEN
                RAISE EXCEPTION 'Student does not meet the prerequisites for this course.';
            END IF;
         END IF;
        -- If we get here, prerequisites are met (or bypassed by admin), register the student.
        INSERT INTO Registered (student, course) VALUES (NEW.student, NEW.course);
        RETURN NULL; -- Stop the original INSERT
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Trigger for INSERT on Registrations view
CREATE OR REPLACE TRIGGER registration_trigger
INSTEAD OF INSERT ON Registrations
FOR EACH ROW
EXECUTE FUNCTION handle_registration();

-- Function to handle unregistration
CREATE OR REPLACE FUNCTION handle_unregistration() RETURNS TRIGGER AS $$
DECLARE
    first_waiting_student TEXT;
BEGIN
    -- Was the student registered or waiting?
    IF OLD.status = 'registered' THEN
        -- Student was registered. Delete from Registered.
        DELETE FROM Registered WHERE student = OLD.student AND course = OLD.course;

        -- Check if the course is limited AND if there are waiters.
        IF EXISTS (SELECT 1 FROM LimitedCourses WHERE code = OLD.course) AND
           EXISTS (SELECT 1 FROM WaitingList WHERE course = OLD.course) THEN

            -- Find the first student in the waiting list who *meets* prerequisites.
            SELECT student INTO first_waiting_student
            FROM WaitingList W
            WHERE W.course = OLD.course
              AND NOT EXISTS (  -- This is the crucial prerequisite check for promotion
                SELECT 1
                FROM Prerequisites p
                WHERE p.course = OLD.course
                  AND NOT EXISTS (
                    SELECT 1
                    FROM Taken t
                    WHERE t.student = W.student AND t.course = p.prerequisite AND t.grade <> 'U'
                  )
              )
            ORDER BY position
            LIMIT 1;

            -- If an eligible waiting student was found, register them.
            IF first_waiting_student IS NOT NULL THEN
                -- Remove from waiting list.
                DELETE FROM WaitingList WHERE student = first_waiting_student AND course = OLD.course;
                -- Register the student.
                INSERT INTO Registered (student, course) VALUES (first_waiting_student, OLD.course);
            END IF;

            -- Correctly update waiting list positions.
            UPDATE WaitingList
            SET position = position - 1
            WHERE course = OLD.course;
        END IF;

    ELSIF OLD.status = 'waiting' THEN
        -- Student was waiting. Delete from WaitingList.
        DELETE FROM WaitingList WHERE student = OLD.student AND course = OLD.course;

        -- Correctly update waiting list positions.
        UPDATE WaitingList
        SET position = position - 1
        WHERE course = OLD.course;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger for DELETE on Registrations view
CREATE OR REPLACE TRIGGER unregistration_trigger
INSTEAD OF DELETE ON Registrations
FOR EACH ROW
EXECUTE FUNCTION handle_unregistration();