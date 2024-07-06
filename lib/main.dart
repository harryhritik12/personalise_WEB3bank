import 'package:flutter/material.dart';
import 'package:web3_flutter/features/dashboard/ui/dashboard_page.dart';
void main(){
  runApp(MyApp());
}
class MyApp extends StatelessWidget{
  const MyApp ({super.key});
  @override
  Widget build(BuildContext context){
    return MaterialApp(
      home:DashboardPage(),
    );
    
  }
}