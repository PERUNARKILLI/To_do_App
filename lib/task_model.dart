class Task {
  String id;
  String title;
  String description;
  DateTime dueDate;
  bool isComplete;
  int priority;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    this.isComplete = false,
    this.priority = 1,
  });
} 