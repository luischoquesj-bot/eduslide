import 'topic_folder.dart';

/// Representa el año de escolaridad de secundaria (primer nivel de carpetas)
/// Ejemplo: "1ero Sec.", "2do Sec.", "3ero Sec.", etc.
class GradeFolder {
  final String id;
  final String name;
  final String path;
  final List<TopicFolder> topics;

  const GradeFolder({
    required this.id,
    required this.name,
    required this.path,
    required this.topics,
  });
}
