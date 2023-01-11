import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarHeader extends StatelessWidget {
  const CalendarHeader({
    Key? key,
    this.handleNextMonth,
    this.handlePreviousMonth,
    required this.initialDate,
  }) : super(key: key);

  final VoidCallback? handleNextMonth;
  final VoidCallback? handlePreviousMonth;
  final DateTime initialDate;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            InkWell(
              onTap: handlePreviousMonth,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 12),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.chevron_left_rounded,
                      color: Color(0xFF7D8499),
                    ),
                    Text(
                      DateFormat('MMMM').format(DateTime(initialDate.year, initialDate.month - 1)),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: Color(0xFF787676),
                        letterSpacing: -0.2,
                      ),
                      // strutStyle: StrutStyles.subheading_14,
                    )
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: handleNextMonth,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Row(
                  children: <Widget>[
                    Text(
                      DateFormat('MMMM').format(DateTime(initialDate.year, initialDate.month + 1)),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: Color(0xFF787676),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF7D8499),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              DateFormat('MMMM yyyy').format(initialDate),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 17,
                color: Color(0xFF1F2021),
                letterSpacing: -0.2,
              ),
            ),
          ],
        )
      ],
    );
  }
}
