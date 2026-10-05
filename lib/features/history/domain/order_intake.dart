/// Захиалга үүсгэх үед бүртгэсэн «Хүлээн авах» тэмдэглэл (зөвхөн унших).
class OrderIntake {
  const OrderIntake({
    required this.recordedAt,
    this.notes,
    this.photos = const [],
    this.signatureUrl,
    this.mileageKm,
  });

  final DateTime recordedAt;
  final String? notes;
  final List<OrderIntakePhoto> photos;

  /// Серверээс ирсэн (ихэвчлэн `/uploads/...` харьцангуй) зам.
  final String? signatureUrl;

  /// Одометрийн заалт (км); оруулаагүй бол null.
  final int? mileageKm;

  /// «152,300 км» (мянгатаар таслалтай); [mileageKm] null бол null.
  String? get mileageLabel {
    final km = mileageKm;
    if (km == null) return null;
    final grouped = km.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '$grouped км';
  }

  bool get hasNotes => notes != null && notes!.trim().isNotEmpty;
}

class OrderIntakePhoto {
  const OrderIntakePhoto({required this.id, required this.url});

  final String id;
  final String url;
}
