import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    super.name = '',
    super.employeeCode = '',
    super.department = '',
    super.designation = '',
    super.location = '',
    super.cardNumber = '',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? json['userid'] ?? json['emp_pk'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      employeeCode: (json['employeeCode'] ?? '').toString(),
      department: (json['department'] ?? '').toString(),
      designation: (json['designation'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      cardNumber: (json['cardNumber'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'employeeCode': employeeCode,
      'department': department,
      'designation': designation,
      'location': location,
      'cardNumber': cardNumber,
    };
  }
}
