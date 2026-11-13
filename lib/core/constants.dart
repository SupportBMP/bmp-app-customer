/// commons/constants.js values the app uses.
library;

const timeSlotOptions = [
  'Morning (2AM to 3AM)',
  'Morning (3AM to 4AM)',
  'Morning (4AM to 5AM)',
  'Morning (5AM to 6AM)',
  'Morning (6AM to 7AM)',
  'Morning (7AM to 8AM)',
  'Morning (8AM to 9AM)',
  'Morning (9AM to 10AM)',
  'Morning (10AM to 11AM)',
  'Morning (11AM to 12PM)',
  'Afternoon (12PM to 1PM)',
  'Afternoon (1PM to 2PM)',
  'Afternoon (2PM to 3PM)',
  'Afternoon (3PM to 4PM)',
  'Evening (4PM to 5PM)',
  'Evening (5PM to 6PM)',
  'Evening (6PM to 7PM)',
  'Evening (7PM to 8PM)',
  'Evening (8PM to 9PM)',
  'Evening (10PM to 11PM)',
];

const poojaBookingStages = ['Booked', 'Assigning Pandit', 'Pandit Assigned', 'Pooja Completed'];

const ePoojaLocationId = '67eabe7700d779b9cf799b27';

/// commons/slotHighlightConfig.js
String? resolveSlotHighlightIcon(String? poojaName, String? location, String? language) {
  bool m(String rule, String? v) => rule == '*' || rule.trim().toLowerCase() == (v ?? '').trim().toLowerCase();
  if (m('Ganesh Sthapana and Visarjan Puja', poojaName) && m('*', location) && m('*', language)) {
    return '/icons/ganpati.svg';
  }
  return null;
}
