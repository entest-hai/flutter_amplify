import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Amplify Flutter Packages
import 'package:amplify_flutter/amplify.dart';
// import 'package:amplify_api/amplify_api.dart'; // UNCOMMENT this line once backend is deployed
import 'package:amplify_datastore/amplify_datastore.dart';

// Generated in previous step
import 'models/ModelProvider.dart';
import 'amplifyconfiguration.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override 
  State<StatefulWidget> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _amplifyConfigured = false;
  @override 
  void initState() {
    // TODO: implement initState
    super.initState();
    _configureAmplify();
  }

  @override 
  Widget build(BuildContext context) {
    // TODO: implement build
    return MaterialApp(
      home: BlocProvider(
        create: (context) => TodoCubit()..getTodos(),
        child:  _amplifyConfigured ? TodosView() : LoadingView(),),
    );
  }

    void _configureAmplify() async {

    // Amplify.addPlugin(AmplifyAPI()); // UNCOMMENT this line once backend is deployed
    Amplify.addPlugin(AmplifyDataStore(modelProvider: ModelProvider.instance));

    // Once Plugins are added, configure Amplify
    try {
      await Amplify.configure(amplifyconfig);
    } catch (e) {
      print(e);
    }

    setState(() {
      _amplifyConfigured = true;
    });
  }
}

class TodosView extends StatefulWidget {
  @override 
  State<StatefulWidget> createState() => _TodosViewState();
}

class _TodosViewState extends State<TodosView> {
  final _titleController = TextEditingController();
  @override 
  Widget build(BuildContext context) {
    // TODO: implement build
     return Scaffold(
       appBar: _navBar(),
       floatingActionButton: _floatingActionButton(),
       body: BlocBuilder<TodoCubit, TodoState>(builder: (context, state) {
         if (state is ListTodosSuccess) {
           return state.todos.isEmpty ? _emptyTodosView() : _todoListView(state.todos);
         } else if (state is ListTodoFailure) {
           return _exceptionView(state.exception);
         } else {
           return LoadingView();
         }
       },),
     );
  }

  Widget _todoListView(List<Todo> todos) {
    return ListView.builder(
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
        return Card(
          child: CheckboxListTile(
            title: Text(todo.title),
            value: todo.isComplete,
            onChanged: (newValue){
              BlocProvider.of<TodoCubit>(context).updateTodoIsComplete(todo, newValue);
            },
            ),
        );
      },
    );
  }

  Widget _exceptionView(Exception exception) {
    return Center(
      child: Text(exception.toString()),
    );
  }

  AppBar _navBar() {
    return AppBar(title: Text("Todos"),);
  }

  Widget _floatingActionButton() {
    return FloatingActionButton(onPressed: (){
      showModalBottomSheet(
      context: context,
      builder: (context){
        return _newTodoView();
      });
    }, child: Icon(Icons.add),);
  }

  Widget _newTodoView() {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(hintText: "Enter todo title"),
        ),
        ElevatedButton(onPressed: (){
          BlocProvider.of<TodoCubit>(context).createTodo(_titleController.text);
          _titleController.text = '';
          Navigator.of(context).pop();

        }, child: Text("Save Todo"))


      ],
    );
  }

  Widget _emptyTodosView() {
    return Center(
      child: Text("No Todo Yet"),
    );
  }
}

class LoadingView extends StatelessWidget {
  @override 
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(
      color: Colors.white,
      child: Center(child: CircularProgressIndicator(),),
    );
  }
}

// Data Repository 
class TodoRepository {
  Future<List<Todo>> getTodos() async {
    try {
      final todos = await Amplify.DataStore.query(Todo.classType);
      return todos;
    } catch (e) {
      throw e; 
    }
  }

  Future<void> createTodo(String title) async {
    final newTodo = Todo(title: title, isComplete: false);
    try {
      return await Amplify.DataStore.save(newTodo);
    } catch(e) {
      throw e; 
    }
  }

  Future<void> updateTodoIsComplete(Todo todo, bool isComplete) async {
    final updatedTodo = todo.copyWith(isComplete: isComplete);
    try {
      await Amplify.DataStore.save(updatedTodo);
    } catch(e) {
      throw e; 
    }
  }
}

// Event and State 
abstract class TodoState {}

class LoadingTodos extends TodoState {}

class ListTodosSuccess extends TodoState {
  final List<Todo> todos; 
  ListTodosSuccess({this.todos});
}

class ListTodoFailure extends TodoState {
  final Exception exception;
  ListTodoFailure({this.exception});
}

class TodoCubit extends Cubit<TodoState> {
  TodoCubit() : super(LoadingTodos());
  final _todoRepo = TodoRepository();

  void getTodos() async {
    if (state is ListTodosSuccess == false) {
      emit(LoadingTodos());
    }
    try {
      final todos = await _todoRepo.getTodos();
      emit(ListTodosSuccess(todos: todos));
    } catch(e) {
      emit(ListTodoFailure(exception: e));
    }
  }

  void updateTodoIsComplete(Todo todo, bool isComplete) async {
    await _todoRepo.updateTodoIsComplete(todo, isComplete);
    getTodos();
  }

  void createTodo(String title) async {
    await _todoRepo.createTodo(title);
    getTodos();
  }
}

// Bloc Map Event To State 

