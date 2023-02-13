import 'package:flutter/material.dart';
class snack{
  SnackBar displaySnackBar(String msg, [Color? backcolor]) {
    final snackBar = SnackBar(
      content: Text(msg,style: const TextStyle(fontSize: 18,fontWeight: FontWeight.bold),),
      backgroundColor: backcolor??Colors.blue[200],
      action: SnackBarAction(
        label: 'Ok',
        onPressed: (){},
      ),
    );
    return snackBar;
  }
}