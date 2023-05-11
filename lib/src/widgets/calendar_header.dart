import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarHeader extends StatelessWidget {
  const CalendarHeader({
    Key? key,
    required this.currentDate,
    required this.onTap,
    required this.displayTodayButton,
  }) : super(key: key);

  final DateTime currentDate;
  final VoidCallback onTap;
  final bool displayTodayButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (displayTodayButton)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16),
            child: InkWell(
              onTap: () {
                onTap();
              },
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Text(
                  'Today',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: Color(0xFF0B80F3),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
        const Spacer(),
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
        const Spacer(),
        if (displayTodayButton)
          // This is used to make sure that current date is centered
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 4, top: 4, bottom: 4, end: 20),
            child: Text(
              'Today',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: Colors.transparent,
                letterSpacing: -0.2,
              ),
            ),
          ),
      ],
    );
  }
}
