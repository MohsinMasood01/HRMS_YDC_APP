import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  const UserEntity({
    required this.id,
    required this.name,
    required this.employeeCode,
    required this.department,
    required this.designation,
    required this.location,
    required this.cardNumber,
  });

  final String id;
  final String name;
  final String employeeCode;
  final String department;
  final String designation;
  final String location;
  final String cardNumber;

  @override
  List<Object?> get props => [
        id,
        name,
        employeeCode,
        department,
        designation,
        location,
        cardNumber,
      ];
}

