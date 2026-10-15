import 'package:equatable/equatable.dart';

class LeaveBalance extends Equatable {
  const LeaveBalance({
    required this.code,
    required this.name,
    required this.balance,
  });

  final String code;
  final String name;
  final int balance;

  @override
  List<Object?> get props => [code, name, balance];
}

