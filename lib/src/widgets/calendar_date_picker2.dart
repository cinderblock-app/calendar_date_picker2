// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:calendar_date_picker2/src/widgets/calendar_header.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:jiffy/jiffy.dart';

const Duration _monthScrollDuration = Duration(milliseconds: 200);

const double _dayPickerRowHeight = 48.0;
const int _yearPickerColumnCount = 3;
const double _yearPickerPadding = 16.0;
const double _yearPickerRowHeight = 52.0;
const double _yearPickerRowSpacing = 8.0;

const double _subHeaderHeight = 52.0;
const double _monthNavButtonsWidth = 108.0;

T? _ambiguate<T>(T? value) => value;

class CalendarDatePicker2 extends StatefulWidget {
  CalendarDatePicker2({
    required this.initialValue,
    required this.config,
    this.onValueChanged,
    this.onDisplayedMonthChanged,
    Key? key,
  }) : super(key: key) {
    const valid = true;
    const invalid = false;

    if (config.calendarType == CalendarDatePicker2Type.single) {
      assert(initialValue.length < 2, 'Error: single date picker only allows maximum one initial date');
    }

    if (config.calendarType == CalendarDatePicker2Type.range && initialValue.length > 1) {
      final isRangePickerValueValid = initialValue[0] == null
          ? (initialValue[1] != null ? invalid : valid)
          : (initialValue[1] != null ? (initialValue[1]!.isBefore(initialValue[0]!) ? invalid : valid) : valid);

      assert(
        isRangePickerValueValid,
        'Error: range date picker must has start date set before setting end date, and start date must before end date.',
      );
    }
  }

  /// The initially selected [DateTime]s that the picker should display.
  final List<DateTime?> initialValue;

  /// Called when the user selects a date in the picker.
  final ValueChanged<List<DateTime?>>? onValueChanged;

  /// Called when the user navigates to a new month/year in the picker.
  final ValueChanged<DateTime>? onDisplayedMonthChanged;

  /// The calendar UI related configurations
  final CalendarDatePicker2Config config;

  @override
  State<CalendarDatePicker2> createState() => _CalendarDatePicker2State();
}

class _CalendarDatePicker2State extends State<CalendarDatePicker2> {
  bool _announcedInitialDate = false;
  late List<DateTime?> _selectedDates;
  late DatePickerMode _mode;
  late DateTime _currentDisplayedMonthDate;
  final GlobalKey _monthPickerKey = GlobalKey();
  final GlobalKey _yearPickerKey = GlobalKey();
  late MaterialLocalizations _localizations;
  late TextDirection _textDirection;

  @override
  void initState() {
    super.initState();
    final config = widget.config;
    final initialDate = widget.initialValue.isNotEmpty && widget.initialValue[0] != null
        ? DateTime(widget.initialValue[0]!.year, widget.initialValue[0]!.month)
        : DateUtils.dateOnly(DateTime.now());
    _mode = config.calendarViewMode;
    _currentDisplayedMonthDate = DateTime(initialDate.year, initialDate.month);
    _selectedDates = widget.initialValue;
  }

  @override
  void didUpdateWidget(CalendarDatePicker2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config.calendarViewMode != oldWidget.config.calendarViewMode) {
      _mode = widget.config.calendarViewMode;
    }
    _selectedDates = widget.initialValue;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    assert(debugCheckHasMaterial(context));
    assert(debugCheckHasMaterialLocalizations(context));
    assert(debugCheckHasDirectionality(context));
    _localizations = MaterialLocalizations.of(context);
    _textDirection = Directionality.of(context);
    if (!_announcedInitialDate && _selectedDates.isNotEmpty) {
      _announcedInitialDate = true;
      for (final date in _selectedDates) {
        if (date != null) {
          SemanticsService.announce(
            _localizations.formatFullDate(date),
            _textDirection,
          );
        }
      }
    }
  }

  void _vibrate() {
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        HapticFeedback.vibrate();
        break;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        break;
    }
  }

  void _handleModeChanged(DatePickerMode mode) {
    _vibrate();
    setState(() {
      _mode = mode;
      if (_selectedDates.isNotEmpty) {
        for (final date in _selectedDates) {
          if (date != null) {
            SemanticsService.announce(
              _mode == DatePickerMode.day ? _localizations.formatMonthYear(date) : _localizations.formatYear(date),
              _textDirection,
            );
          }
        }
      }
    });
  }

  void _handleMonthChanged(DateTime date, {bool fromYearPicker = false}) {
    setState(() {
      final currentDisplayedMonthDate = DateTime(
        _currentDisplayedMonthDate.year,
        _currentDisplayedMonthDate.month,
      );
      var newDisplayedMonthDate = currentDisplayedMonthDate;

      if (_currentDisplayedMonthDate.year != date.year || _currentDisplayedMonthDate.month != date.month) {
        newDisplayedMonthDate = DateTime(date.year, date.month);
      }

      if (fromYearPicker) {
        final selectedDatesInThisYear = widget.initialValue.where((d) => d?.year == date.year).toList()
          ..sort((d1, d2) => d1!.compareTo(d2!));
        if (selectedDatesInThisYear.isNotEmpty) {
          newDisplayedMonthDate = DateTime(date.year, selectedDatesInThisYear[0]!.month);
        }
      }

      if (currentDisplayedMonthDate.year != newDisplayedMonthDate.year ||
          currentDisplayedMonthDate.month != newDisplayedMonthDate.month) {
        _currentDisplayedMonthDate = DateTime(
          newDisplayedMonthDate.year,
          newDisplayedMonthDate.month,
        );
        widget.onDisplayedMonthChanged?.call(_currentDisplayedMonthDate);
      }
    });
  }

  void _handleYearChanged(DateTime value) {
    _vibrate();

    if (value.isBefore(widget.config.firstDate)) {
      value = widget.config.firstDate;
    } else if (value.isAfter(widget.config.lastDate)) {
      value = widget.config.lastDate;
    }

    setState(() {
      _mode = DatePickerMode.day;
      _handleMonthChanged(value, fromYearPicker: true);
    });
  }

  void _handleDayChanged(DateTime value) {
    _vibrate();
    setState(() {
      var selectedDates = [..._selectedDates];
      selectedDates.removeWhere((d) => d == null);

      if (widget.config.calendarType == CalendarDatePicker2Type.single) {
        selectedDates = [value];
      } else if (widget.config.calendarType == CalendarDatePicker2Type.multi) {
        final index = selectedDates.indexWhere((d) => DateUtils.isSameDay(d, value));
        if (index != -1) {
          selectedDates.removeAt(index);
        } else {
          selectedDates.add(value);
        }
      } else if (widget.config.calendarType == CalendarDatePicker2Type.range) {
        if (selectedDates.isEmpty) {
          selectedDates.add(value);
        } else {
          final isRangeSet = selectedDates.length > 1 && selectedDates[1] != null;
          final isSelectedDayBeforeStartDate = value.isBefore(selectedDates[0]!);

          if (isRangeSet || isSelectedDayBeforeStartDate) {
            selectedDates = [value, null];
          } else {
            selectedDates = [selectedDates[0], value];
          }
        }
      }

      selectedDates
        ..removeWhere((d) => d == null)
        ..sort((d1, d2) => d1!.compareTo(d2!));

      final isValueDifferent = widget.config.calendarType != CalendarDatePicker2Type.single ||
          !DateUtils.isSameDay(selectedDates[0], _selectedDates.isNotEmpty ? _selectedDates[0] : null);
      if (isValueDifferent) {
        _selectedDates = _selectedDates
          ..clear()
          ..addAll(selectedDates);
        widget.onValueChanged?.call(_selectedDates);
      }
    });
  }

  Widget _buildPicker() {
    switch (_mode) {
      case DatePickerMode.day:
        return _MonthPicker(
          config: widget.config,
          key: _monthPickerKey,
          initialMonth: _currentDisplayedMonthDate,
          selectedDates: _selectedDates,
          onChanged: _handleDayChanged,
          onDisplayedMonthChanged: _handleMonthChanged,
        );
      case DatePickerMode.year:
        return Padding(
          padding: EdgeInsets.only(top: widget.config.controlsHeight ?? _subHeaderHeight),
          child: YearPicker(
            config: widget.config,
            key: _yearPickerKey,
            initialMonth: _currentDisplayedMonthDate,
            selectedDates: _selectedDates,
            onChanged: _handleYearChanged,
          ),
        );
    }
  }

  int _numberOfWeeksThisMonth() {
    _currentDisplayedMonthDate;
    //print("_currentDisplayedMonthDate _currentDisplayedMonthDate ${_currentDisplayedMonthDate}");
    final numberOfDays = DateTime(_currentDisplayedMonthDate.year, _currentDisplayedMonthDate.month + 1, 0).day;
    final List<int> weeks = <int>[];
    for (int i = 1; i <= numberOfDays; i++) {
      final int week = Jiffy(DateTime(_currentDisplayedMonthDate.year, _currentDisplayedMonthDate.month, i)).week;
      if (!weeks.contains(week)) {
        weeks.add(week);
      }
    }

    return weeks.length;
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    assert(debugCheckHasMaterialLocalizations(context));
    assert(debugCheckHasDirectionality(context));

    final maxDayPickerRowCount = _numberOfWeeksThisMonth();
    // NOTE: 22 is the header (title) height
    final height = _dayPickerRowHeight * (maxDayPickerRowCount) + 22;
    return Stack(
      children: <Widget>[
        SizedBox(
          height: (widget.config.controlsHeight ?? _subHeaderHeight) + height,
          child: _buildPicker(),
        ),
        // Put the mode toggle button on top so that it won't be covered up by the _MonthPicker
        _DatePickerModeToggleButton(
          config: widget.config,
          mode: _mode,
          title: _localizations.formatMonthYear(_currentDisplayedMonthDate),
          onTitlePressed: () {
            // Toggle the day/year mode.
            _handleModeChanged(_mode == DatePickerMode.day ? DatePickerMode.year : DatePickerMode.day);
          },
        ),
      ],
    );
  }
}

/// A button that used to toggle the [DatePickerMode] for a date picker.
///
/// This appears above the calendar grid and allows the user to toggle the
/// [DatePickerMode] to display either the calendar view or the year list.
class _DatePickerModeToggleButton extends StatefulWidget {
  const _DatePickerModeToggleButton({
    required this.mode,
    required this.title,
    required this.onTitlePressed,
    required this.config,
  });

  /// The current display of the calendar picker.
  final DatePickerMode mode;

  /// The text that displays the current month/year being viewed.
  final String title;

  /// The callback when the title is pressed.
  final VoidCallback onTitlePressed;

  /// The calendar configurations
  final CalendarDatePicker2Config config;

  @override
  _DatePickerModeToggleButtonState createState() => _DatePickerModeToggleButtonState();
}

class _DatePickerModeToggleButtonState extends State<_DatePickerModeToggleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: widget.mode == DatePickerMode.year ? 0.5 : 0,
      upperBound: 0.5,
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(_DatePickerModeToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode == widget.mode) {
      return;
    }

    if (widget.mode == DatePickerMode.year) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (widget.mode == DatePickerMode.day)
          // Give space for the prev/next month buttons that are underneath this row
          const SizedBox(width: _monthNavButtonsWidth),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _MonthPicker extends StatefulWidget {
  /// Creates a month picker.
  const _MonthPicker({
    required this.config,
    required this.initialMonth,
    required this.selectedDates,
    required this.onChanged,
    required this.onDisplayedMonthChanged,
    Key? key,
  }) : super(key: key);

  /// The calendar configurations
  final CalendarDatePicker2Config config;

  /// The initial month to display.
  final DateTime initialMonth;

  /// The currently selected dates.
  ///
  /// Selected dates are highlighted in the picker.
  final List<DateTime?> selectedDates;

  /// Called when the user picks a day.
  final ValueChanged<DateTime> onChanged;

  /// Called when the user navigates to a new month.
  final ValueChanged<DateTime> onDisplayedMonthChanged;

  @override
  _MonthPickerState createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  final GlobalKey _pageViewKey = GlobalKey();
  late DateTime _currentMonth;
  late PageController _pageController;
  late MaterialLocalizations _localizations;
  late TextDirection _textDirection;
  Map<ShortcutActivator, Intent>? _shortcutMap;
  Map<Type, Action<Intent>>? _actionMap;
  late FocusNode _dayGridFocus;
  DateTime? _focusedDay;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.initialMonth;
    _pageController = PageController(initialPage: DateUtils.monthDelta(widget.config.firstDate, _currentMonth));
    _shortcutMap = const <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(TraversalDirection.left),
      SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(TraversalDirection.right),
      SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(TraversalDirection.down),
      SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(TraversalDirection.up),
    };
    _actionMap = <Type, Action<Intent>>{
      NextFocusIntent: CallbackAction<NextFocusIntent>(onInvoke: _handleGridNextFocus),
      PreviousFocusIntent: CallbackAction<PreviousFocusIntent>(onInvoke: _handleGridPreviousFocus),
      DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(onInvoke: _handleDirectionFocus),
    };
    _dayGridFocus = FocusNode(debugLabel: 'Day Grid');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _localizations = MaterialLocalizations.of(context);
    _textDirection = Directionality.of(context);
  }

  @override
  void didUpdateWidget(_MonthPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMonth != oldWidget.initialMonth && widget.initialMonth != _currentMonth) {
      // We can't interrupt this widget build with a scroll, so do it next frame
      // Add workaround to fix Flutter 3.0.0 compiler issue
      // https://github.com/flutter/flutter/issues/103561#issuecomment-1125512962
      // https://github.com/flutter/website/blob/3e6d87f13ad2a8dd9cf16081868cc3b3794abb90/src/development/tools/sdk/release-notes/release-notes-3.0.0.md#your-code
      _ambiguate(WidgetsBinding.instance)!.addPostFrameCallback(
        (Duration timeStamp) => _showMonth(widget.initialMonth, jump: true),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _dayGridFocus.dispose();
    super.dispose();
  }

  void _handleDateSelected(DateTime selectedDate) {
    _focusedDay = selectedDate;
    widget.onChanged(selectedDate);
  }

  void _handleMonthPageChanged(int monthPage) {
    setState(() {
      final DateTime monthDate = DateUtils.addMonthsToMonthDate(widget.config.firstDate, monthPage);
      if (!DateUtils.isSameMonth(_currentMonth, monthDate)) {
        _currentMonth = DateTime(monthDate.year, monthDate.month);
        widget.onDisplayedMonthChanged(_currentMonth);
        if (_focusedDay != null && !DateUtils.isSameMonth(_focusedDay, _currentMonth)) {
          // We have navigated to a new month with the grid focused, but the
          // focused day is not in this month. Choose a new one trying to keep
          // the same day of the month.
          _focusedDay = _focusableDayForMonth(_currentMonth, _focusedDay!.day);
        }
        SemanticsService.announce(
          _localizations.formatMonthYear(_currentMonth),
          _textDirection,
        );
      }
    });
  }

  /// Returns a focusable date for the given month.
  ///
  /// If the preferredDay is available in the month it will be returned,
  /// otherwise the first selectable day in the month will be returned. If
  /// no dates are selectable in the month, then it will return null.
  DateTime? _focusableDayForMonth(DateTime month, int preferredDay) {
    final int daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);

    // Can we use the preferred day in this month?
    if (preferredDay <= daysInMonth) {
      final DateTime newFocus = DateTime(month.year, month.month, preferredDay);
      if (_isSelectable(newFocus)) return newFocus;
    }

    // Start at the 1st and take the first selectable date.
    for (int day = 1; day <= daysInMonth; day++) {
      final DateTime newFocus = DateTime(month.year, month.month, day);
      if (_isSelectable(newFocus)) return newFocus;
    }
    return null;
  }

  // /// Navigate to the next month.
  // void _handleNextMonth() {
  //   if (!_isDisplayingLastMonth) {
  //     _pageController.nextPage(
  //       duration: _monthScrollDuration,
  //       curve: Curves.ease,
  //     );
  //   }
  // }
  //
  // /// Navigate to the previous month.
  // void _handlePreviousMonth() {
  //   if (!_isDisplayingFirstMonth) {
  //     _pageController.previousPage(
  //       duration: _monthScrollDuration,
  //       curve: Curves.ease,
  //     );
  //   }
  // }

  /// Navigate to the given month.
  void _showMonth(DateTime month, {bool jump = false}) {
    final int monthPage = DateUtils.monthDelta(widget.config.firstDate, month);
    if (jump) {
      _pageController.jumpToPage(monthPage);
    } else {
      _pageController.animateToPage(
        monthPage,
        duration: _monthScrollDuration,
        curve: Curves.ease,
      );
    }
  }

  // /// True if the earliest allowable month is displayed.
  // bool get _isDisplayingFirstMonth {
  //   return !_currentMonth.isAfter(
  //     DateTime(widget.config.firstDate.year, widget.config.firstDate.month),
  //   );
  // }

  // /// True if the latest allowable month is displayed.
  // bool get _isDisplayingLastMonth {
  //   return !_currentMonth.isBefore(
  //     DateTime(widget.config.lastDate.year, widget.config.lastDate.month),
  //   );
  // }

  /// Handler for when the overall day grid obtains or loses focus.
  void _handleGridFocusChange(bool focused) {
    setState(() {
      if (focused && _focusedDay == null && widget.selectedDates.isNotEmpty) {
        if (DateUtils.isSameMonth(widget.selectedDates[0], _currentMonth)) {
          _focusedDay = widget.selectedDates[0];
        } else if (DateUtils.isSameMonth(widget.config.currentDate, _currentMonth)) {
          _focusedDay = _focusableDayForMonth(_currentMonth, widget.config.currentDate.day);
        } else {
          _focusedDay = _focusableDayForMonth(_currentMonth, 1);
        }
      }
    });
  }

  /// Move focus to the next element after the day grid.
  void _handleGridNextFocus(NextFocusIntent intent) {
    _dayGridFocus.requestFocus();
    _dayGridFocus.nextFocus();
  }

  /// Move focus to the previous element before the day grid.
  void _handleGridPreviousFocus(PreviousFocusIntent intent) {
    _dayGridFocus.requestFocus();
    _dayGridFocus.previousFocus();
  }

  /// Move the internal focus date in the direction of the given intent.
  ///
  /// This will attempt to move the focused day to the next selectable day in
  /// the given direction. If the new date is not in the current month, then
  /// the page view will be scrolled to show the new date's month.
  ///
  /// For horizontal directions, it will move forward or backward a day (depending
  /// on the current [TextDirection]). For vertical directions it will move up and
  /// down a week at a time.
  void _handleDirectionFocus(DirectionalFocusIntent intent) {
    setState(() {
      if (_focusedDay != null) {
        final nextDate = _nextDateInDirection(_focusedDay!, intent.direction);
        if (nextDate != null) {
          _focusedDay = nextDate;
          if (!DateUtils.isSameMonth(_focusedDay, _currentMonth)) {
            _showMonth(_focusedDay!);
          }
        }
      } else {
        _focusedDay ??= widget.initialMonth;
      }
    });
  }

  static const Map<TraversalDirection, int> _directionOffset = <TraversalDirection, int>{
    TraversalDirection.up: -DateTime.daysPerWeek,
    TraversalDirection.right: 1,
    TraversalDirection.down: DateTime.daysPerWeek,
    TraversalDirection.left: -1,
  };

  int _dayDirectionOffset(TraversalDirection traversalDirection, TextDirection textDirection) {
    // Swap left and right if the text direction if RTL
    if (textDirection == TextDirection.rtl) {
      if (traversalDirection == TraversalDirection.left) {
        traversalDirection = TraversalDirection.right;
      } else if (traversalDirection == TraversalDirection.right) {
        traversalDirection = TraversalDirection.left;
      }
    }
    return _directionOffset[traversalDirection]!;
  }

  DateTime? _nextDateInDirection(DateTime date, TraversalDirection direction) {
    final TextDirection textDirection = Directionality.of(context);
    DateTime nextDate = DateUtils.addDaysToDate(date, _dayDirectionOffset(direction, textDirection));
    while (!nextDate.isBefore(widget.config.firstDate) && !nextDate.isAfter(widget.config.lastDate)) {
      if (_isSelectable(nextDate)) {
        return nextDate;
      }
      nextDate = DateUtils.addDaysToDate(nextDate, _dayDirectionOffset(direction, textDirection));
    }
    return null;
  }

  bool _isSelectable(DateTime date) {
    return widget.config.selectableDayPredicate?.call(date) ?? true;
  }

  Widget _buildItems(BuildContext context, int index, VoidCallback scrollToDate) {
    final DateTime month = DateUtils.addMonthsToMonthDate(widget.config.firstDate, index);
    return _DayPicker(
      key: ValueKey<DateTime>(month),
      selectedDates: (widget.selectedDates..removeWhere((d) => d == null)).cast<DateTime>(),
      onChanged: _handleDateSelected,
      config: widget.config,
      displayedMonth: month,
      scrollToDate: scrollToDate,
    );
  }

  void _scrollToDate(DateTime date) {
    final currentMonthPage = DateUtils.monthDelta(widget.config.firstDate, date);
    _pageController.animateToPage(
      currentMonthPage,
      duration: const Duration(milliseconds: 500),
      curve: Curves.ease,
    );
    _handleDateSelected(date);
  }

  void _scrollToToday() {
    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );
    _scrollToDate(today);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      child: FocusableActionDetector(
        shortcuts: _shortcutMap,
        actions: _actionMap,
        focusNode: _dayGridFocus,
        onFocusChange: _handleGridFocusChange,
        child: _FocusedDate(
          date: _dayGridFocus.hasFocus ? _focusedDay : null,
          child: PageView.builder(
            key: _pageViewKey,
            controller: _pageController,
            itemBuilder: (BuildContext context, int index) {
              return _buildItems(context, index, _scrollToToday);
            },
            itemCount: DateUtils.monthDelta(widget.config.firstDate, widget.config.lastDate) + 1,
            onPageChanged: _handleMonthPageChanged,
          ),
        ),
      ),
    );
  }
}

/// InheritedWidget indicating what the current focused date is for its children.
///
/// This is used by the [_MonthPicker] to let its children [_DayPicker]s know
/// what the currently focused date (if any) should be.
class _FocusedDate extends InheritedWidget {
  const _FocusedDate({
    Key? key,
    required Widget child,
    this.date,
  }) : super(key: key, child: child);

  final DateTime? date;

  @override
  bool updateShouldNotify(_FocusedDate oldWidget) {
    return !DateUtils.isSameDay(date, oldWidget.date);
  }

  static DateTime? maybeOf(BuildContext context) {
    final _FocusedDate? focusedDate = context.dependOnInheritedWidgetOfExactType<_FocusedDate>();
    return focusedDate?.date;
  }
}

/// Displays the days of a given month and allows choosing a day.
///
/// The days are arranged in a rectangular grid with one column for each day of
/// the week.
class _DayPicker extends StatefulWidget {
  /// Creates a day picker.
  const _DayPicker({
    required this.config,
    required this.displayedMonth,
    required this.selectedDates,
    required this.onChanged,
    required this.scrollToDate,
    Key? key,
  }) : super(key: key);

  /// The calendar configurations
  final CalendarDatePicker2Config config;

  /// The currently selected dates.
  ///
  /// Selected dates are highlighted in the picker.
  final List<DateTime> selectedDates;

  /// Called when the user picks a day.
  final ValueChanged<DateTime> onChanged;

  /// The month whose days are displayed by this picker.
  final DateTime displayedMonth;

  final VoidCallback scrollToDate;

  @override
  _DayPickerState createState() => _DayPickerState();
}

class _DayPickerState extends State<_DayPicker> {
  /// List of [FocusNode]s, one for each day of the month.
  late List<FocusNode> _dayFocusNodes;

  @override
  void initState() {
    super.initState();
    final int daysInMonth = DateUtils.getDaysInMonth(widget.displayedMonth.year, widget.displayedMonth.month);
    _dayFocusNodes = List<FocusNode>.generate(
      daysInMonth,
      (int index) => FocusNode(skipTraversal: true, debugLabel: 'Day ${index + 1}'),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check to see if the focused date is in this month, if so focus it.
    final DateTime? focusedDate = _FocusedDate.maybeOf(context);
    if (focusedDate != null && DateUtils.isSameMonth(widget.displayedMonth, focusedDate)) {
      _dayFocusNodes[focusedDate.day - 1].requestFocus();
    }
  }

  @override
  void dispose() {
    for (final FocusNode node in _dayFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// Builds widgets showing abbreviated days of week. The first widget in the
  /// returned list corresponds to the first day of week for the current locale.
  ///
  /// Examples:
  ///
  /// ```
  /// ┌ Sunday is the first day of week in the US (en_US)
  /// |
  /// S M T W T F S  <-- the returned list contains these widgets
  /// _ _ _ _ _ 1 2
  /// 3 4 5 6 7 8 9
  ///
  /// ┌ But it's Monday in the UK (en_GB)
  /// |
  /// M T W T F S S  <-- the returned list contains these widgets
  /// _ _ _ _ 1 2 3
  /// 4 5 6 7 8 9 10
  /// ```
  List<Widget> _dayHeaders(TextStyle? headerStyle, MaterialLocalizations localizations) {
    final List<Widget> result = <Widget>[];
    final weekdays = widget.config.weekdayLabels ?? localizations.narrowWeekdays;
    final firstDayOfWeek = widget.config.firstDayOfWeek ?? localizations.firstDayOfWeekIndex;
    assert(firstDayOfWeek >= 0 && firstDayOfWeek <= 6, 'firstDayOfWeek must between 0 and 6');
    for (int i = firstDayOfWeek; true; i = (i + 1) % 7) {
      final String weekday = weekdays[i];
      result.add(ExcludeSemantics(
        child: Center(
          child: Text(
            weekday,
            style: widget.config.weekdayLabelTextStyle ?? headerStyle,
          ),
        ),
      ));
      if (i == (firstDayOfWeek - 1) % 7) break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle? headerStyle = textTheme.bodySmall?.apply(
      color: colorScheme.onSurface.withOpacity(0.60),
    );
    final TextStyle dayStyle = textTheme.bodySmall!;
    final Color enabledDayColor = colorScheme.onSurface.withOpacity(0.87);
    final Color disabledDayColor = colorScheme.onSurface.withOpacity(0.38);
    final Color selectedDayColor = colorScheme.onPrimary;
    final Color selectedDayBackground = colorScheme.primary;
    final Color todayColor = colorScheme.primary;

    final int year = widget.displayedMonth.year;
    final int month = widget.displayedMonth.month;

    final int daysInMonth = DateUtils.getDaysInMonth(year, month);
    final int dayOffset =
        getMonthFirstDayOffset(year, month, widget.config.firstDayOfWeek ?? localizations.firstDayOfWeekIndex);

    final List<Widget> dayItems = _dayHeaders(headerStyle, localizations);
    // 1-based day of month, e.g. 1-31 for January, and 1-29 for February on
    // a leap year.
    int day = -dayOffset;
    while (day < daysInMonth) {
      day++;
      if (day < 1) {
        dayItems.add(Container());
      } else {
        final DateTime dayToBuild = DateTime(year, month, day);
        final bool isDisabled = dayToBuild.isAfter(widget.config.lastDate) ||
            dayToBuild.isBefore(widget.config.firstDate) ||
            !(widget.config.selectableDayPredicate?.call(dayToBuild) ?? true);
        final bool isSelectedDay = widget.selectedDates.any((d) => DateUtils.isSameDay(d, dayToBuild));

        final bool isToday = DateUtils.isSameDay(widget.config.currentDate, dayToBuild);

        BoxDecoration? decoration;
        Color dayColor = enabledDayColor;
        if (isSelectedDay) {
          // The selected day gets a circle background highlight, and a
          // contrasting text color.
          dayColor = selectedDayColor;
          decoration = BoxDecoration(
            borderRadius: widget.config.dayBorderRadius,
            color: widget.config.selectedDayHighlightColor ?? selectedDayBackground,
            shape: widget.config.dayBorderRadius != null ? BoxShape.rectangle : BoxShape.circle,
          );
        } else if (isDisabled) {
          dayColor = disabledDayColor;
        } else if (isToday) {
          // The current day gets a different text color and a circle stroke
          // border.
          dayColor = widget.config.todayHighlightColor ?? todayColor;
          decoration = BoxDecoration(
            borderRadius: widget.config.dayBorderRadius,
            color: dayColor,
            shape: widget.config.dayBorderRadius != null ? BoxShape.rectangle : BoxShape.circle,
          );
        }

        var customDayTextStyle =
            widget.config.dayTextStylePredicate?.call(date: dayToBuild) ?? widget.config.dayTextStyle;

        if (isToday && widget.config.todayTextStyle != null) {
          customDayTextStyle = widget.config.todayTextStyle;
        }

        if (isDisabled) {
          customDayTextStyle = customDayTextStyle?.copyWith(
            color: disabledDayColor,
            fontWeight: FontWeight.normal,
          );
          if (widget.config.disabledDayTextStyle != null) {
            customDayTextStyle = widget.config.disabledDayTextStyle;
          }
        }

        if (isSelectedDay) {
          customDayTextStyle = widget.config.selectedDayTextStyle;
        }

        final dayTextStyle = customDayTextStyle ?? dayStyle.apply(color: dayColor);

        Widget dayWidget = widget.config.dayBuilder?.call(
              date: dayToBuild,
              textStyle: dayTextStyle,
              decoration: decoration,
              isSelected: isSelectedDay,
              isDisabled: isDisabled,
              isToday: isToday,
            ) ??
            _buildDefaultDayWidgetContent(
              decoration,
              localizations,
              day,
              dayTextStyle,
            );

        if (widget.config.calendarType == CalendarDatePicker2Type.range) {
          if (widget.selectedDates.length == 2) {
            final startDate = DateUtils.dateOnly(widget.selectedDates[0]);
            final endDate = DateUtils.dateOnly(widget.selectedDates[1]);
            final isDateInRange = !(dayToBuild.isBefore(startDate) || dayToBuild.isAfter(endDate));
            final isStartDateSameToEndDate = DateUtils.isSameDay(startDate, endDate);

            if (isDateInRange && !isStartDateSameToEndDate) {
              final rangePickerIncludedDayDecoration = BoxDecoration(
                color: (widget.config.selectedDayHighlightColor ?? selectedDayBackground).withOpacity(0.15),
              );

              if (DateUtils.isSameDay(startDate, dayToBuild)) {
                dayWidget = Stack(
                  children: [
                    Row(children: [
                      const Spacer(),
                      Expanded(
                        child: Container(decoration: rangePickerIncludedDayDecoration),
                      ),
                    ]),
                    dayWidget,
                  ],
                );
              } else if (DateUtils.isSameDay(endDate, dayToBuild)) {
                dayWidget = Stack(
                  children: [
                    Row(children: [
                      Expanded(
                        child: Container(decoration: rangePickerIncludedDayDecoration),
                      ),
                      const Spacer(),
                    ]),
                    dayWidget,
                  ],
                );
              } else {
                dayWidget = Stack(
                  children: [
                    Container(decoration: rangePickerIncludedDayDecoration),
                    dayWidget,
                  ],
                );
              }
            }
          }
        }

        if (isDisabled) {
          dayWidget = ExcludeSemantics(
            child: dayWidget,
          );
        } else {
          dayWidget = InkResponse(
            focusNode: _dayFocusNodes[day - 1],
            onTap: () => widget.onChanged(dayToBuild),
            radius: _dayPickerRowHeight / 2 + 4,
            splashColor: selectedDayBackground.withOpacity(0.38),
            child: Semantics(
              // We want the day of month to be spoken first irrespective of the
              // locale-specific preferences or TextDirection. This is because
              // an accessibility user is more likely to be interested in the
              // day of month before the rest of the date, as they are looking
              // for the day of month. To do that we prepend day of month to the
              // formatted full date.
              label: '${localizations.formatDecimal(day)}, ${localizations.formatFullDate(dayToBuild)}',
              selected: isSelectedDay,
              excludeSemantics: true,
              child: dayWidget,
            ),
          );
        }

        dayItems.add(dayWidget);
      }
    }

    final List<int> weeks = <int>[];
    for (int i = 1; i <= daysInMonth; i++) {
      final int week = Jiffy(DateTime(year, month, i)).week;
      if (!weeks.contains(week)) {
        weeks.add(week);
      }
    }
    // Note: we add +1  because of headers (name of the week days)
    final height = _dayPickerRowHeight * (weeks.length + 1);

    final bool displayTodayButton =
        widget.config.displayTodayButton && DateTime.now().year == year && DateTime.now().month == month;
    return SizedBox(
      height: height,
      child: Column(
        children: <Widget>[
          CalendarHeader(
            currentDate: widget.displayedMonth,
            onTap: widget.scrollToDate,
            displayTodayButton: displayTodayButton,
          ),
          Expanded(
            child: GridView.custom(
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              gridDelegate: _dayPickerGridDelegate,
              childrenDelegate: SliverChildListDelegate(
                dayItems,
                addRepaintBoundaries: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultDayWidgetContent(
    BoxDecoration? decoration,
    MaterialLocalizations localizations,
    int day,
    TextStyle dayTextStyle,
  ) {
    return Row(
      children: [
        const Spacer(),
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: decoration,
            child: Center(
              child: Text(
                localizations.formatDecimal(day),
                style: dayTextStyle,
              ),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

class _DayPickerGridDelegate extends SliverGridDelegate {
  const _DayPickerGridDelegate();

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    const int columnCount = DateTime.daysPerWeek;
    final double tileWidth = constraints.crossAxisExtent / columnCount;
    const double tileHeight = _dayPickerRowHeight;
    return SliverGridRegularTileLayout(
      childCrossAxisExtent: tileWidth,
      childMainAxisExtent: tileHeight,
      crossAxisCount: columnCount,
      crossAxisStride: tileWidth,
      mainAxisStride: tileHeight,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(_DayPickerGridDelegate oldDelegate) => false;
}

const _DayPickerGridDelegate _dayPickerGridDelegate = _DayPickerGridDelegate();

/// A scrollable grid of years to allow picking a year.
///
/// The year picker widget is rarely used directly. Instead, consider using
/// [CalendarDatePicker2], or [showDatePicker2] which create full date pickers.
///
/// See also:
///
///  * [CalendarDatePicker2], which provides a Material Design date picker
///    interface.
///
///  * [showDatePicker2], which shows a dialog containing a Material Design
///    date picker.
///
class YearPicker extends StatefulWidget {
  /// Creates a year picker.
  const YearPicker({
    required this.config,
    required this.selectedDates,
    required this.onChanged,
    required this.initialMonth,
    this.dragStartBehavior = DragStartBehavior.start,
    Key? key,
  }) : super(key: key);

  /// The calendar configurations
  final CalendarDatePicker2Config config;

  /// The currently selected dates.
  ///
  /// Selected dates are highlighted in the picker.
  final List<DateTime?> selectedDates;

  /// Called when the user picks a year.
  final ValueChanged<DateTime> onChanged;

  /// The initial month to display.
  final DateTime initialMonth;

  /// {@macro flutter.widgets.scrollable.dragStartBehavior}
  final DragStartBehavior dragStartBehavior;

  @override
  State<YearPicker> createState() => _YearPickerState();
}

class _YearPickerState extends State<YearPicker> {
  late ScrollController _scrollController;

  // The approximate number of years necessary to fill the available space.
  static const int minYears = 18;

  @override
  void initState() {
    super.initState();
    final scrollOffset = widget.selectedDates.isNotEmpty && widget.selectedDates[0] != null
        ? _scrollOffsetForYear(widget.selectedDates[0]!)
        : _scrollOffsetForYear(DateUtils.dateOnly(DateTime.now()));
    _scrollController = ScrollController(initialScrollOffset: scrollOffset);
  }

  @override
  void didUpdateWidget(YearPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDates != oldWidget.selectedDates) {
      final scrollOffset = widget.selectedDates.isNotEmpty && widget.selectedDates[0] != null
          ? _scrollOffsetForYear(widget.selectedDates[0]!)
          : _scrollOffsetForYear(DateUtils.dateOnly(DateTime.now()));
      _scrollController.jumpTo(scrollOffset);
    }
  }

  double _scrollOffsetForYear(DateTime date) {
    final int initialYearIndex = date.year - widget.config.firstDate.year;
    final int initialYearRow = initialYearIndex ~/ _yearPickerColumnCount;
    // Move the offset down by 2 rows to approximately center it.
    final int centeredYearRow = initialYearRow - 2;
    return _itemCount < minYears ? 0 : centeredYearRow * _yearPickerRowHeight;
  }

  Widget _buildYearItem(BuildContext context, int index) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Backfill the _YearPicker with disabled years if necessary.
    final int offset = _itemCount < minYears ? (minYears - _itemCount) ~/ 2 : 0;
    final int year = widget.config.firstDate.year + index - offset;
    final bool isSelected = widget.selectedDates.any((d) => d?.year == year);
    final bool isCurrentYear = year == widget.config.currentDate.year;
    final bool isDisabled = year < widget.config.firstDate.year || year > widget.config.lastDate.year;
    const double decorationHeight = 36.0;
    const double decorationWidth = 72.0;

    final Color textColor;
    if (isSelected) {
      textColor = colorScheme.onPrimary;
    } else if (isDisabled) {
      textColor = colorScheme.onSurface.withOpacity(0.38);
    } else if (isCurrentYear) {
      textColor = widget.config.selectedDayHighlightColor ?? colorScheme.primary;
    } else {
      textColor = colorScheme.onSurface.withOpacity(0.87);
    }
    TextStyle? itemStyle = widget.config.yearTextStyle ?? textTheme.bodyText1?.apply(color: textColor);
    if (isSelected) {
      itemStyle = widget.config.selectedYearTextStyle ?? itemStyle;
    }

    BoxDecoration? decoration;
    if (isSelected) {
      decoration = BoxDecoration(
        color: widget.config.selectedDayHighlightColor ?? colorScheme.primary,
        borderRadius: widget.config.yearBorderRadius ?? BorderRadius.circular(decorationHeight / 2),
      );
    } else if (isCurrentYear && !isDisabled) {
      decoration = BoxDecoration(
        border: Border.all(
          color: widget.config.selectedDayHighlightColor ?? colorScheme.primary,
        ),
        borderRadius: widget.config.yearBorderRadius ?? BorderRadius.circular(decorationHeight / 2),
      );
    }

    Widget yearItem = Center(
      child: Container(
        decoration: decoration,
        height: decorationHeight,
        width: decorationWidth,
        child: Center(
          child: Semantics(
            selected: isSelected,
            button: true,
            child: Text(
              year.toString(),
              style: itemStyle,
            ),
          ),
        ),
      ),
    );

    if (isDisabled) {
      yearItem = ExcludeSemantics(
        child: yearItem,
      );
    } else {
      yearItem = InkWell(
        key: ValueKey<int>(year),
        onTap: () => widget.onChanged(
          DateTime(
            year,
            widget.initialMonth.month,
          ),
        ),
        child: yearItem,
      );
    }

    return yearItem;
  }

  int get _itemCount {
    return widget.config.lastDate.year - widget.config.firstDate.year + 1;
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    return Column(
      children: <Widget>[
        const Divider(),
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            dragStartBehavior: widget.dragStartBehavior,
            gridDelegate: _yearPickerGridDelegate,
            itemBuilder: _buildYearItem,
            itemCount: math.max(_itemCount, minYears),
            padding: const EdgeInsets.symmetric(horizontal: _yearPickerPadding),
          ),
        ),
        const Divider(),
      ],
    );
  }
}

class _YearPickerGridDelegate extends SliverGridDelegate {
  const _YearPickerGridDelegate();

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final double tileWidth =
        (constraints.crossAxisExtent - (_yearPickerColumnCount - 1) * _yearPickerRowSpacing) / _yearPickerColumnCount;
    return SliverGridRegularTileLayout(
      childCrossAxisExtent: tileWidth,
      childMainAxisExtent: _yearPickerRowHeight,
      crossAxisCount: _yearPickerColumnCount,
      crossAxisStride: tileWidth + _yearPickerRowSpacing,
      mainAxisStride: _yearPickerRowHeight,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(_YearPickerGridDelegate oldDelegate) => false;
}

const _YearPickerGridDelegate _yearPickerGridDelegate = _YearPickerGridDelegate();
