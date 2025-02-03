-- Create basic tables
CREATE TABLE Students (
    idnr CHAR(10) PRIMARY KEY CHECK (idnr ~ '^[0-9]{10}$'),
    name TEXT NOT NULL,
    login TEXT NOT NULL UNIQUE,
    program TEXT NOT NULL
);

CREATE TABLE Branches (
    name TEXT,
    program TEXT,
    PRIMARY KEY (name, program)
);

CREATE TABLE Courses (
    code CHAR(6) PRIMARY KEY CHECK (code ~ '^[A-Z]{3}[0-9]{3}$'),
    name TEXT NOT NULL,
    credits FLOAT NOT NULL CHECK (credits > 0),
    department TEXT NOT NULL
);

CREATE TABLE LimitedCourses (
    code CHAR(6) PRIMARY KEY REFERENCES Courses(code),
    capacity INT NOT NULL CHECK (capacity > 0)
);

CREATE TABLE StudentBranches (
    student CHAR(10) PRIMARY KEY REFERENCES Students(idnr),
    branch TEXT NOT NULL,
    program TEXT NOT NULL,
    FOREIGN KEY (branch, program) REFERENCES Branches(name, program),
    FOREIGN KEY (student) REFERENCES Students(idnr)
);

CREATE TABLE Classifications (
    name TEXT PRIMARY KEY
);

CREATE TABLE Classified (
    course CHAR(6) REFERENCES Courses(code),
    classification TEXT REFERENCES Classifications(name),
    PRIMARY KEY (course, classification)
);

CREATE TABLE MandatoryProgram (
    course CHAR(6) REFERENCES Courses(code),
    program TEXT NOT NULL,
    PRIMARY KEY (course, program)
);

CREATE TABLE MandatoryBranch (
    course CHAR(6) REFERENCES Courses(code),
    branch TEXT,
    program TEXT,
    PRIMARY KEY (course, branch, program),
    FOREIGN KEY (branch, program) REFERENCES Branches(name, program)
);

CREATE TABLE RecommendedBranch (
    course CHAR(6) REFERENCES Courses(code),
    branch TEXT,
    program TEXT,
    PRIMARY KEY (course, branch, program),
    FOREIGN KEY (branch, program) REFERENCES Branches(name, program)
);

CREATE TABLE Registered (
    student CHAR(10) REFERENCES Students(idnr),
    course CHAR(6) REFERENCES Courses(code),
    PRIMARY KEY (student, course)
);

CREATE TABLE Taken (
    student CHAR(10) REFERENCES Students(idnr),
    course CHAR(6) REFERENCES Courses(code),
    grade CHAR(1) NOT NULL CHECK (grade IN ('U', '3', '4', '5')),
    PRIMARY KEY (student, course)
);

CREATE TABLE WaitingList (
    student CHAR(10) REFERENCES Students(idnr),
    course CHAR(6) REFERENCES LimitedCourses(code),
    position INT NOT NULL CHECK (position > 0),
    PRIMARY KEY (student, course),
    UNIQUE (course, position)
);
