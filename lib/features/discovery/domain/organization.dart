import 'package:carservice_customer/features/discovery/domain/branch.dart';

class Organization {
  const Organization({
    required this.slug,
    required this.name,
    required this.branches,
    this.logoUrl,
    this.bookable = true,
  });
  final String slug;
  final String name;
  final String? logoUrl;
  final List<Branch> branches;

  /// Онлайн цаг захиалга авдаг эсэх (API `bookable`, байхгүй бол `true`).
  /// Mobile API одоогоор зөвхөн захиалга авдаг газрыг буцаадаг тул үргэлж
  /// `true` — `false` ирвэл «Цаг захиалах» товчийг нуух урьдчилсан бэлтгэл.
  final bool bookable;
}

class OrganizationDetail {
  const OrganizationDetail({
    required this.slug,
    required this.name,
    required this.branches,
    this.logoUrl,
    this.phone,
    this.bookable = true,
  });

  /// [Organization.bookable]-тай ижил — API ирүүлбэл л `false` болно.
  final bool bookable;
  final String slug;
  final String name;
  final String? logoUrl;
  final String? phone;
  final List<BranchDetail> branches;
}
