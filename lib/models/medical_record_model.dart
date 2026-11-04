class MedicalRecordModel {
  final String id;
  final String patientId;
  final String doctorId;
  final String diagnosis;
  final String treatment;
  final String? notes;
  final DateTime recordDate;

  MedicalRecordModel({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.diagnosis,
    required this.treatment,
    this.notes,
    DateTime? recordDate,
  }) : recordDate = recordDate ?? DateTime.now();

  factory MedicalRecordModel.fromJson(Map<String, dynamic> json) {
    return MedicalRecordModel(
      id: json['id'] ?? '',
      patientId: json['patientId'] ?? '',
      doctorId: json['doctorId'] ?? '',
      diagnosis: json['diagnosis'] ?? '',
      treatment: json['treatment'] ?? '',
      notes: json['notes'],
      recordDate: DateTime.tryParse(json['recordDate'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'diagnosis': diagnosis,
      'treatment': treatment,
      'notes': notes,
      'recordDate': recordDate.toIso8601String(),
    };
  }
}
