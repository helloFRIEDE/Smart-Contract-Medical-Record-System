// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract MedicalRecord {
    struct Patient {
        uint256 no;
        address patientAddress;
        string name;
        uint256 age;
        address primaryDoctor;
    }

    struct Doctor {
        uint256 no;
        address doctorAddress;
        string name;
        uint256 age;
    }

    struct MedicalRecordEntry {
        uint256 recordNo;
        string description;
        string date;
        address doctor;
    }

    mapping(address => Patient) private patients;
    mapping(address => Doctor) private doctors;
    mapping(address => bool) private doctorAddresses;
    mapping(uint256 => address) private patientNumbers;
    mapping(uint256 => address) public doctorNumbers;
    mapping(address => MedicalRecordEntry[]) private medicalRecords;
    mapping(address => address[]) private doctorPatients;

    address public owner;
    uint256 patientNumber;
    uint256 public doctorNumber;

    event PatientAdded(address indexed patientAddress, string name, uint256 age, address indexed primaryDoctor);
    event MedicalRecordAdded(address indexed patientAddress, uint256 recordNo, address indexed doctor, string date);
    event PrimaryDoctorChanged(address indexed patientAddress, address indexed oldDoctor, address indexed newDoctor);
    event DoctorAdded(address indexed doctorAddress, string name, uint256 age);
    event DoctorRevoked(address indexed doctorAddress);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier onlyDoctor(address add) {
        require(doctorAddresses[add], "Only doctors can perform this action");
        _;
    }

    modifier onlyPrimaryDoctor(address _patientAddress) {
        require(patients[_patientAddress].primaryDoctor == msg.sender, "Only the primary doctor can perform this action");
        _;
    }

    modifier onlyPatientOrDoctor(address myAdd, address _patientAddress) {
        require(patients[_patientAddress].patientAddress != address(0), "Patient not found");
        require(myAdd == _patientAddress || doctorAddresses[myAdd], "Only the patient or doctors can perform this action");
        _;
    }

    modifier onlyPatientOrPrimaryDoctor(address myAdd, address _patientAddress) {
        require(patients[_patientAddress].patientAddress != address(0), "Patient not found");
        require(myAdd == _patientAddress || patients[_patientAddress].primaryDoctor == myAdd, "Only the patient or the primary doctor can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
        patientNumber = 0;
        doctorNumber = 0;
    }

    function addPatient(address _patientAddress, string memory _name, uint256 _age, address _primaryDoctor) public onlyDoctor(msg.sender) returns (string memory) {
        require(doctorAddresses[_primaryDoctor], "Primary doctor not found in database");
        require(_age > 0, "Invalid age");
        require(patients[_patientAddress].patientAddress == address(0), "Patient already exists");

        patientNumber++;
        patients[_patientAddress] = Patient(patientNumber, _patientAddress, _name, _age, _primaryDoctor);
        patientNumbers[patientNumber] = _patientAddress;
        doctorPatients[_primaryDoctor].push(_patientAddress);

        emit PatientAdded(_patientAddress, _name, _age, _primaryDoctor);
        return "success";
    }

    function addMedicalRecord(address _patientAddress, string memory _description, string memory _date) public onlyPrimaryDoctor(_patientAddress) {
        uint256 recordNo = (patients[_patientAddress].no * 1000) + medicalRecords[_patientAddress].length + 1;
        medicalRecords[_patientAddress].push(MedicalRecordEntry(recordNo, _description, _date, msg.sender));

        emit MedicalRecordAdded(_patientAddress, recordNo, msg.sender, _date);
    }

    function _removePatientFromDoctor(address _doctor, address _patientAddress) internal {
        address[] storage patientList = doctorPatients[_doctor];
        for (uint256 i = 0; i < patientList.length; i++) {
            if (patientList[i] == _patientAddress) {
                patientList[i] = patientList[patientList.length - 1];
                patientList.pop();
                break;
            }
        }
    }

    function changePrimaryDoctor(address _patientAddress, address _newPrimaryDoctor) public onlyPrimaryDoctor(_patientAddress) {
        require(doctorAddresses[_newPrimaryDoctor], "New primary doctor must be a registered doctor");

        address oldDoctor = patients[_patientAddress].primaryDoctor;
        _removePatientFromDoctor(oldDoctor, _patientAddress);

        patients[_patientAddress].primaryDoctor = _newPrimaryDoctor;
        doctorPatients[_newPrimaryDoctor].push(_patientAddress);

        emit PrimaryDoctorChanged(_patientAddress, oldDoctor, _newPrimaryDoctor);
    }

    function getMedicalRecords(address myAdd, address _patientAddress) public view onlyPatientOrPrimaryDoctor(myAdd, _patientAddress) returns (MedicalRecordEntry[] memory) {
        return medicalRecords[_patientAddress];
    }

    function _parseYear(string memory date) private pure returns (uint256) {
        bytes memory dateBytes = bytes(date);
        require(dateBytes.length >= 4, "Invalid date format");

        uint256 year;
        for (uint256 i = 0; i < 4; i++) {
            year = year * 10 + (uint8(dateBytes[i]) - 48);
        }

        return year;
    }

    function getMedicalRecordsByYear(address myAdd, address _patientAddress, uint256 _year) public view onlyPatientOrPrimaryDoctor(myAdd, _patientAddress) returns (MedicalRecordEntry[] memory) {
        MedicalRecordEntry[] memory allRecords = medicalRecords[_patientAddress];
        uint256 count = 0;

        for (uint256 i = 0; i < allRecords.length; i++) {
            uint256 recordYear = _parseYear(allRecords[i].date);
            if (recordYear == _year) {
                count++;
            }
        }

        MedicalRecordEntry[] memory recordsByYear = new MedicalRecordEntry[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allRecords.length; i++) {
            uint256 recordYear = _parseYear(allRecords[i].date);
            if (recordYear == _year) {
                recordsByYear[index] = allRecords[i];
                index++;
            }
        }

        return recordsByYear;
    }

    function getPatientDetailsByAddress(address myAdd, address _patientAddress) public view onlyPatientOrDoctor(myAdd, _patientAddress) returns (uint256, address, string memory, uint256, address) {
        Patient memory patient = patients[_patientAddress];
        return (patient.no, patient.patientAddress, patient.name, patient.age, patient.primaryDoctor);
    }

    function getPatientDetailsByNumber(address myAdd, uint256 _no) public view onlyPatientOrDoctor(myAdd, patientNumbers[_no]) returns (uint256, address, string memory, uint256, address) {
        address patientAddress = patientNumbers[_no];
        Patient memory patient = patients[patientAddress];
        return (patient.no, patient.patientAddress, patient.name, patient.age, patient.primaryDoctor);
    }
    
    function getPatientsByDoctor(address myAdd, address _doctorAddress) public view returns (address[] memory) {
        /*address[] memory a = new address[](0);
        if (doctorAddresses[myAdd] == false)
            return a;*/
        require(myAdd == _doctorAddress, "You can't access the list of patients under other doctors.");
        return doctorPatients[_doctorAddress];
    }

    function addDoctor(address _doctorAddress, string memory _name, uint256 _age) public onlyOwner {
        require(!doctorAddresses[_doctorAddress], "Doctor already registered");
        require(_age > 0, "Invalid age");

        doctorNumber++;
        doctors[_doctorAddress] = Doctor(doctorNumber, _doctorAddress, _name, _age);
        doctorNumbers[doctorNumber] = _doctorAddress;
        doctorAddresses[_doctorAddress] = true;

        emit DoctorAdded(_doctorAddress, _name, _age);
    }

    function revokeDoctorRole(address _doctorAddress) public onlyOwner {
        require(doctorAddresses[_doctorAddress], "Doctor not found");

        doctorAddresses[_doctorAddress] = false;
        delete doctors[_doctorAddress];  // delete _doctorAddress from mapping
        doctorNumber--;
        
        emit DoctorRevoked(_doctorAddress);
    }

    function checkAddressRole(address _address) public view returns (string memory) {
        bool isDoctor = doctorAddresses[_address];
        bool isPatient = patients[_address].patientAddress != address(0);

        if (isDoctor && isPatient) {
            return "Both";
        } else if (isDoctor) {
            return "Doctor";
        } else if (isPatient) {
            return "Patient";
        } else {
            return "None";
        }
    }

    function getDoctorDetailsByAddress(address _doctorAddress) public view returns (uint256, address, string memory, uint256) {
        Doctor memory doctor = doctors[_doctorAddress];
        return (doctor.no, doctor.doctorAddress, doctor.name, doctor.age);
    }

    function getDoctorDetailsByNumber(uint256 _no) public view returns (uint256, address, string memory, uint256) {
        address doctorAddress = doctorNumbers[_no];
        Doctor memory doctor = doctors[doctorAddress];
        return (doctor.no, doctor.doctorAddress, doctor.name, doctor.age);
    }

    function getPatientsByName(address myAdd, string memory _name) public view onlyDoctor(myAdd) returns (address[] memory) { // 
        uint256 count = 0;
        for (uint256 i = 1; i <= patientNumber; i++) {
            if (keccak256(abi.encodePacked(patients[patientNumbers[i]].name)) == keccak256(abi.encodePacked(_name))) {
                count++;
            }
        }

        address[] memory patientAddresses = new address[](count);
        uint256 index = 0;
        for (uint256 i = 1; i <= patientNumber; i++) {
            if (keccak256(abi.encodePacked(patients[patientNumbers[i]].name)) == keccak256(abi.encodePacked(_name))) {
                patientAddresses[index] = patientNumbers[i];
                index++;
            }
        }
        return patientAddresses;
    }
}
