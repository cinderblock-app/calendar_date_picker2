import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarHeader extends StatelessWidget {
  const CalendarHeader({Key? key, required this.currentDate}) : super(key: key);

  final DateTime currentDate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          DateFormat('MMMM yyyy').format(currentDate),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 17,
            color: Color(0xFF1F2021),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}
