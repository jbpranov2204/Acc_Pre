
import 'package:flutter/material.dart';
import 'package:myapp/Login_Page/login.dart';

void main(){
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      
      theme: ThemeData(
         brightness: Brightness.light
         
         
      ),
        home:LoginPage(),
        debugShowCheckedModeBanner: false,

    );
  }
}