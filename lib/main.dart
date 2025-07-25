import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'task_model.dart';
import 'task_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo Task Management',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const TodoHomePage();
        }
        return const SignInPage();
      },
    );
  }
}

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});
  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in aborted')));
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign in failed: $e')));
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Sign in with Google'),
          onPressed: () => _signInWithGoogle(context),
        ),
      ),
    );
  }
}

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});
  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
}

  void _showTaskDialog(BuildContext context, {Task? task}) {
    final isEditing = task != null;
    final titleController = TextEditingController(text: task?.title ?? '');
    final descController = TextEditingController(text: task?.description ?? '');
    DateTime? dueDate = task?.dueDate;
    int priority = task?.priority ?? 1;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Task' : 'Add Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    Row(
                      children: [
                        const Text('Due Date: '),
                        Text(dueDate != null ? DateFormat.yMd().format(dueDate!) : 'Not set'),
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dueDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => dueDate = picked);
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Priority: '),
                        DropdownButton<int>(
                          value: priority,
                          items: [1, 2, 3, 4, 5]
                              .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                              .toList(),
                          onChanged: (val) => setState(() => priority = val ?? 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;
                    final provider = Provider.of<TaskProvider>(context, listen: false);
                    if (isEditing) {
                      provider.updateTask(Task(
                        id: task!.id,
                        title: titleController.text.trim(),
                        description: descController.text.trim(),
                        dueDate: dueDate ?? DateTime.now(),
                        isComplete: task.isComplete,
                        priority: priority,
                      ));
                    } else {
                      provider.addTask(Task(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: titleController.text.trim(),
                        description: descController.text.trim(),
                        dueDate: dueDate ?? DateTime.now(),
                        priority: priority,
                      ));
                    }
                    Navigator.pop(context);
                  },
                  child: Text(isEditing ? 'Update' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    List<Task> tasks = taskProvider.tasks;
    if (_searchQuery.isNotEmpty) {
      tasks = tasks.where((t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    List<Task> openTasks = tasks.where((t) => !t.isComplete).toList();
    List<Task> completedTasks = tasks.where((t) => t.isComplete).toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'Todo Tasks',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 28,
                color: Colors.deepPurple,
              ),
            ),
            Spacer(),
            GestureDetector(
              onTap: () {
                FirebaseAuth.instance.signOut();
              },
              child: CircleAvatar(
                backgroundColor: Colors.deepPurple.shade100,
                child: Icon(Icons.person, color: Colors.deepPurple),
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade100, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search tasks',
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTaskList(tasks),
                  _buildTaskList(openTasks),
                  _buildTaskList(completedTasks, showDelete: true),
                ],
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskDialog(context),
        icon: Icon(Icons.add),
        label: Text('Add Task'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabController.index,
        onTap: (index) => setState(() => _tabController.index = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'All'),
          BottomNavigationBarItem(icon: Icon(Icons.radio_button_unchecked), label: 'Open'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: 'Completed'),
        ],
        selectedItemColor: Colors.deepPurple,
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks, {bool showDelete = false}) {
    if (tasks.isEmpty) {
      return const Center(child: Text('No tasks yet.'));
    }
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 10,
          shadowColor: Colors.deepPurple.withOpacity(0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: task.isComplete ? Colors.green[50] : Colors.white,
          child: ListTile(
            leading: Icon(Icons.check_circle,
                color: task.isComplete ? Colors.green : Colors.deepPurple, size: 32),
            title: Text(
              task.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: task.isComplete ? Colors.green : Colors.deepPurple,
              ),
            ),
            subtitle: Text(
              '${task.description}\nDue: ${DateFormat.yMd().format(task.dueDate)}',
              style: TextStyle(fontSize: 14),
            ),
            trailing: showDelete
                ? IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => taskProvider.deleteTask(task.id),
                  )
                : Checkbox(
                    value: task.isComplete,
                    onChanged: (_) => taskProvider.toggleComplete(task.id),
                    activeColor: Colors.deepPurple,
                  ),
            onTap: () => _showTaskDialog(context, task: task),
            onLongPress: () => taskProvider.deleteTask(task.id),
          ),
    );
      },
    );
}
}

