import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreUtils {
  // Convierte cualquier tipo de timestamp a DateTime
  static DateTime? toDateTime(dynamic timestamp) {
    if (timestamp == null) return null;
    
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    
    if (timestamp is DateTime) {
      return timestamp;
    }
    
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }

  // Convierte DateTime a Timestamp para Firestore
  static dynamic fromDateTime(DateTime? dateTime) {
    if (dateTime == null) return null;
    return Timestamp.fromDate(dateTime);
  }

  // Obtiene FieldValue.serverTimestamp() para escritura
  static FieldValue get serverTimestamp => FieldValue.serverTimestamp();
}