-- This file will contain all your tables
CREATE TABLE Programs (
    name TEXT PRIMARY KEY,
    abbreviation TEXT
);
--**********************************************************************************************************************
CREATE TABLE Departments (
    name TEXT PRIMARY KEY,
    abbreviation TEXT UNIQUE
);
--**********************************************************************************************************************
CREATE TABLE Students (
    idnr TEXT PRIMARY KEY CHECK (idnr LIKE '__________'),
    name TEXT NOT NULL,
    login TEXT NOT NULL UNIQUE,
    program TEXT NOT NULL,
    FOREIGN KEY (program) REFERENCES Programs(name),
	UNIQUE(idnr, program)
);
--**********************************************************************************************************************
CREATE TABLE Branches (
	name TEXT,
	program TEXT,
	PRIMARY KEY (name, program)
);
--**********************************************************************************************************************
CREATE TABLE Courses (
    code CHAR(6) PRIMARY KEY,
    name TEXT NOT NULL,
    credits NUMERIC(5,1) NOT NULL CHECK (credits > 0),
    department TEXT NOT NULL,
    FOREIGN KEY (department) REFERENCES Departments(name)
);
--**********************************************************************************************************************
CREATE TABLE LimitedCourses (
	code CHAR(6) PRIMARY KEY,
	capacity INT NOT NULL,
	FOREIGN KEY (code) REFERENCES Courses(code) ON DELETE CASCADE ON UPDATE CASCADE
);
--**********************************************************************************************************************
CREATE TABLE StudentBranches (
    student TEXT PRIMARY KEY,
    branch TEXT NOT NULL,
    program TEXT NOT NULL,
    FOREIGN KEY (student, program) REFERENCES Students(idnr, program) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (branch, program) REFERENCES Branches(name, program)ON DELETE CASCADE ON UPDATE CASCADE 
);
--**********************************************************************************************************************
CREATE TABLE Classifications (
	name TEXT PRIMARY KEY
);
--**********************************************************************************************************************
CREATE TABLE Classified (
	course CHAR(6),
	classification TEXT,
	PRIMARY KEY (course, classification),
	FOREIGN KEY (course) REFERENCES Courses(code) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (classification) REFERENCES Classifications(name) ON DELETE CASCADE ON UPDATE CASCADE
);
--**********************************************************************************************************************
CREATE TABLE MandatoryProgram (
	course CHAR(6),
	program TEXT,
	PRIMARY KEY (course, program),
	FOREIGN KEY (course) REFERENCES Courses(code) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (program) REFERENCES Programs(name) ON DELETE CASCADE ON UPDATE CASCADE 
);
--**********************************************************************************************************************
CREATE TABLE MandatoryBranch (
	course CHAR(6),
	branch TEXT,
	program TEXT,
	PRIMARY KEY (course, branch, program),
	FOREIGN KEY (course) REFERENCES Courses(code) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (branch, program) REFERENCES Branches(name, program) ON DELETE CASCADE ON UPDATE CASCADE
);
--**********************************************************************************************************************
CREATE TABLE RecommendedBranch (
	course CHAR(6),
	branch TEXT,
	program TEXT,
	PRIMARY KEY (course, branch, program),
	FOREIGN KEY (course) REFERENCES Courses(code) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (branch, program) REFERENCES Branches(name, program) ON DELETE CASCADE ON UPDATE CASCADE
);
--**********************************************************************************************************************
CREATE TABLE Registered (
	student TEXT,
	course CHAR(6),
	PRIMARY KEY (student, course),
	FOREIGN KEY (student) REFERENCES Students(idnr) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (course) REFERENCES Courses(code) ON DELETE CASCADE ON UPDATE CASCADE
);
--**********************************************************************************************************************
CREATE TABLE Taken (
	student TEXT,
	course CHAR(6),
	grade CHAR(1) NOT NULL CHECK (grade IN ('U', '3', '4', '5')),
	PRIMARY KEY (student, course), 
	FOREIGN KEY (student) REFERENCES Students(idnr) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (course) REFERENCES Courses(code) ON DELETE CASCADE ON UPDATE CASCADE
);
--**********************************************************************************************************************
CREATE TABLE WaitingList (
	student TEXT,
	course CHAR(6),
	position INT NOT NULL CHECK (position > 0),
	PRIMARY KEY (student, course),
	UNIQUE (course, position),
	FOREIGN KEY (student) REFERENCES Students(idnr) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (course) REFERENCES LimitedCourses(code) ON DELETE CASCADE ON UPDATE CASCADE
);
--**********************************************************************************************************************
CREATE TABLE PartOf (
    program TEXT,
    department TEXT,
    PRIMARY KEY (program, department),
    FOREIGN KEY (program) REFERENCES Programs(name),
    FOREIGN KEY (department) REFERENCES Departments(name)
);

--**********************************************************************************************************************
CREATE TABLE Prerequisites (
    course CHAR(6),
    prerequisite CHAR(6),
    PRIMARY KEY (course, prerequisite),
    FOREIGN KEY (course) REFERENCES Courses(code),
    FOREIGN KEY (prerequisite) REFERENCES Courses(code),
    CHECK (course != prerequisite)
);


--**********************************************************************************************************************