import 'package:equatable/equatable.dart';

class ProjectEntity extends Equatable {
  final String id, name, province, district, commune;
  final String forestType, treeSpecies, ownerId, ownerName;
  final int    yearPlanted;
  final double areaHa;
  final String status; // draft | surveying | active | suspended
  final double? latitude, longitude;

  const ProjectEntity({required this.id,required this.name,
    required this.province,required this.district,required this.commune,
    required this.forestType,required this.treeSpecies,
    required this.ownerId,required this.ownerName,
    required this.yearPlanted,required this.areaHa,
    required this.status,this.latitude,this.longitude});

  String get statusLabel{switch(status){
    case 'active':    return 'Đang hoạt động';
    case 'surveying': return 'Đang khảo sát';
    case 'suspended': return 'Tạm dừng';
    default:          return 'Nháp';
  }}
  @override List<Object?> get props=>[id,name,status];
}
