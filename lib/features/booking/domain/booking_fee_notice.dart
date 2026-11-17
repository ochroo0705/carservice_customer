/// Онлайн цаг захиалгын хураамж — захиалга илгээхээс ӨМНӨ харуулна
/// (`GET /api/v1/app/booking-fee` → `{ fee: { amount, ttlMinutes } | null }`).
/// `null` (энэ төрөл биш) бол үнэгүй. Хураамжтай бол захиалга үүссэнээс хойш
/// [ttlMinutes] минутын дотор QPay-ээр төлөхгүй бол цаг чөлөөлөгдөнө.
class BookingFeeNotice {
  const BookingFeeNotice({required this.amount, required this.ttlMinutes});

  final int amount;
  final int ttlMinutes;

  /// Төлөх эцсийн мөч: захиалга үүссэн мөч + [ttlMinutes].
  DateTime payByFrom(DateTime createdAt) =>
      createdAt.add(Duration(minutes: ttlMinutes));
}

/// `HH:mm` Улаанбаатарын цагаар (UTC+8, DST-гүй) — төхөөрөмжийн timezone-оос
/// үл хамааран сервисийн цагтай ижил харагдана.
String ulaanbaatarClock(DateTime moment) {
  final ub = moment.toUtc().add(const Duration(hours: 8));
  final hh = ub.hour.toString().padLeft(2, '0');
  final mm = ub.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
