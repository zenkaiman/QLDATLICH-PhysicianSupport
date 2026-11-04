class DoctorModel {
  final String id;
  final String fullName;
  final String specialty;
  final String hospitalId;
  final String phone;
  final String email;
  final double rating;
  final bool isAvailable;

  DoctorModel({
    required this.id,
    required this.fullName,
    required this.specialty,
    required this.hospitalId,
    required this.phone,
    required this.email,
    this.rating = 4.8,
    this.isAvailable = true,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      specialty: json['specialty'] ?? '',
      hospitalId: json['hospitalId'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      isAvailable: json['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'specialty': specialty,
      'hospitalId': hospitalId,
      'phone': phone,
      'email': email,
      'rating': rating,
      'isAvailable': isAvailable,
    };
  }
}
