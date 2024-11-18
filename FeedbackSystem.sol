// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract FeedbackSystem {
    // State variables for ownership and roles
    address private owner;
    mapping(address => bool) private teachers;
    mapping(address => bool) private students;
    mapping(address => bool) private recruiters;
    mapping(string => bool) private studentRollNumbers; // Track valid roll numbers
    mapping(address => string) private studentRollNumberMap; // Map addresses to roll numbers
    mapping(address => string) private teacherCodeMap; // Map teacher addresses to teacher codes

    // Structs for Teacher Data and Review
    struct TeacherData {
        string code;
        string[] subjectCodes;
        mapping(string => uint256[]) passwordMap;
        mapping(string => Review[]) reviewMap;
    }

    // Structs for Student Data
    struct StudentData {
        string rollNumber;
        mapping(uint256 => string) semesterGradeSheetMap; // Added for semester-specific grade sheets
    }

    struct Review {
        uint256 rating;
        string comments;
    }

    // State variables for teachers and used passwords
    mapping(string => TeacherData) private teachersData;
    mapping(string => StudentData) private studentsData;
    mapping(uint256 => bool) private usedPasswords;

    // Events
    event TeacherAdded(address indexed teacher, string teacherCode);
    event TeacherRemoved(address indexed teacher, string teacherCode);
    event StudentAdded(address indexed student, string rollNumber);
    event StudentRemoved(address indexed student, string rollNumber);
    event RecruiterAdded(address indexed recruiter);
    event RecruiterRemoved(address indexed recruiter);
    event ReviewAdded(
        string indexed teacherCode,
        string indexed subjectCode,
        uint256 rating
    );
    event GradeSheetUploaded(
        string indexed rollNumber,
        uint256 indexed semester,
        string ipfsHash
    );

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyTeacher() {
        require(teachers[msg.sender], "Not authorized");
        _;
    }

    modifier onlyStudent() {
        require(students[msg.sender], "Not authorized");
        _;
    }

    modifier onlyRecruiter() {
        require(recruiters[msg.sender], "Not authorized");
        _;
    }

    modifier checkEitherOwnerOrTeacher(string memory _teacherCode) {
        require(
            msg.sender == owner ||
                keccak256(abi.encodePacked(teacherCodeMap[msg.sender])) ==
                keccak256(abi.encodePacked(_teacherCode)),
            "Not authorized"
        );
        _;
    }

    modifier checkStudentAccess(string memory rollNumber) {
        require(
            keccak256(abi.encodePacked(studentRollNumberMap[msg.sender])) ==
                keccak256(abi.encodePacked(rollNumber)),
            "Not authorized student"
        );
        _;
    }

    modifier checkValidSemester(uint256 semester) {
        require(semester > 0, "Invalid semester number");
        _;
    }

    // Constructor to initialize owner
    constructor() {
        owner = msg.sender;
    }

    // Function to add a teacher
    function addTeacher(
        address teacherAddress,
        string memory _teacherCode,
        string[] memory _subjectCodes,
        uint256[] memory _studentCount
    ) public onlyOwner {
        require(!teachers[teacherAddress], "Address is already a teacher");
        teachers[teacherAddress] = true;
        teacherCodeMap[teacherAddress] = _teacherCode; // Map teacher address to teacher code

        TeacherData storage teacherData = teachersData[_teacherCode];
        teacherData.code = _teacherCode;
        teacherData.subjectCodes = _subjectCodes;

        for (uint256 i = 0; i < _subjectCodes.length; i++) {
            uint256[] memory passwords = new uint256[](_studentCount[i]);
            for (uint256 j = 0; j < _studentCount[i]; j++) {
                uint256 password = uint256(
                    keccak256(
                        abi.encodePacked(
                            teacherAddress,
                            _teacherCode,
                            _subjectCodes[i],
                            j
                        )
                    )
                ) % 100000;
                passwords[j] = password;
            }
            teacherData.passwordMap[_subjectCodes[i]] = passwords;
        }

        emit TeacherAdded(teacherAddress, _teacherCode);
    }

    // Function to remove a teacher
    function removeTeacher(address teacherAddress) public onlyOwner {
        require(teachers[teacherAddress], "Address is not a teacher");
        string memory teacherCode = teacherCodeMap[teacherAddress];
        teachers[teacherAddress] = false;
        delete teacherCodeMap[teacherAddress]; // Remove the teacher code mapping
        emit TeacherRemoved(teacherAddress, teacherCode);
    }

    // Function to add a student
    function addStudent(address studentAddress, string memory _rollNumber)
        public
        onlyOwner
    {
        require(!students[studentAddress], "Address is already a student");
        students[studentAddress] = true;
        studentRollNumbers[_rollNumber] = true; // Track roll number
        studentRollNumberMap[studentAddress] = _rollNumber; // Associate address with roll number
        StudentData storage studentData = studentsData[_rollNumber];
        studentData.rollNumber = _rollNumber;
        emit StudentAdded(studentAddress, _rollNumber);
    }

    // Function to remove a student
    function removeStudent(address studentAddress, string memory _rollNumber)
        public
        onlyOwner
    {
        require(students[studentAddress], "Address is not a student");
        students[studentAddress] = false;
        studentRollNumbers[_rollNumber] = false; // Untrack roll number
        delete studentRollNumberMap[studentAddress]; // Clear the roll number mapping
        emit StudentRemoved(studentAddress, _rollNumber);
    }

    // Function to add a recruiter
    function addRecruiter(address recruiterAddress) public onlyOwner {
        require(
            !recruiters[recruiterAddress],
            "Address is already a recruiter"
        );
        recruiters[recruiterAddress] = true;
        emit RecruiterAdded(recruiterAddress);
    }

    // Function to remove a recruiter
    function removeRecruiter(address recruiterAddress) public onlyOwner {
        require(recruiters[recruiterAddress], "Address is not a recruiter");
        recruiters[recruiterAddress] = false;
        emit RecruiterRemoved(recruiterAddress);
    }

    // Function to get teacher data
    function getTeacher(string memory _teacherCode)
        public
        view
        checkEitherOwnerOrTeacher(_teacherCode)
        returns (string memory code, string[] memory subjectCodes)
    {
        TeacherData storage teacher = teachersData[_teacherCode];
        return (teacher.code, teacher.subjectCodes);
    }

    // Function to get passwords for a subject
    function getPasswords(
        string memory _teacherCode,
        string memory _subjectCode
    )
        public
        view
        checkEitherOwnerOrTeacher(_teacherCode)
        returns (uint256[] memory passwords)
    {
        return teachersData[_teacherCode].passwordMap[_subjectCode];
    }

    // Function to get reviews for a subject
    function getReview(string memory _teacherCode, string memory _subjectCode)
        public
        view
        checkEitherOwnerOrTeacher(_teacherCode)
        returns (Review[] memory)
    {
        return teachersData[_teacherCode].reviewMap[_subjectCode];
    }

    // Function to add a review
    function addReview(
        string memory _teacherCode,
        string memory _subjectCode,
        uint256 _rating,
        string memory _comments,
        uint256 _password
    ) public onlyStudent {
        uint256[] memory passwords = teachersData[_teacherCode].passwordMap[
            _subjectCode
        ];
        require(passwords.length > 0, "Invalid teacher or subject code");
        require(!usedPasswords[_password], "Password has already been used");

        bool passwordMatch = false;
        for (uint256 i = 0; i < passwords.length; i++) {
            if (passwords[i] == _password) {
                passwordMatch = true;
                break;
            }
        }
        require(passwordMatch, "Invalid password");
        usedPasswords[_password] = true;

        teachersData[_teacherCode].reviewMap[_subjectCode].push(
            Review(_rating, _comments)
        );
        emit ReviewAdded(_teacherCode, _subjectCode, _rating);
    }

    // Function to upload a grade sheet for a specific semester
    function uploadGradeSheet(
        string memory _rollNumber,
        uint256 _semester,
        string memory ipfsHash
    ) public onlyOwner checkValidSemester(_semester) {
        studentsData[_rollNumber].semesterGradeSheetMap[_semester] = ipfsHash;
        emit GradeSheetUploaded(_rollNumber, _semester, ipfsHash);
    }

    // Function to get a grade sheet for a specific semester
    function getGradeSheet(uint256 _semester)
        public
        view
        checkValidSemester(_semester)
        returns (string memory)
    {
        string memory rollNumber = studentRollNumberMap[msg.sender];
        require(
            bytes(rollNumber).length > 0,
            "Not authorized or student not found"
        );

        string memory ipfsHash = studentsData[rollNumber].semesterGradeSheetMap[
            _semester
        ];
        require(bytes(ipfsHash).length > 0, "Grade sheet not available");

        return ipfsHash;
    }

    // Function to get a grade sheet for recruiters
    function getGradeSheetForRecruiter(
        string memory _rollNumber,
        uint256 _semester
    ) public view checkValidSemester(_semester) returns (string memory) {
        require(
            msg.sender == owner || recruiters[msg.sender],
            "Not authorized"
        );
        require(studentRollNumbers[_rollNumber], "Not a student");

        string memory ipfsHash = studentsData[_rollNumber]
            .semesterGradeSheetMap[_semester];
        require(bytes(ipfsHash).length > 0, "Grade sheet not available");

        return ipfsHash;
    }
}
