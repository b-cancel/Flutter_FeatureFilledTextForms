import 'package:flutter/material.dart';

import 'Examples/signUp.dart';

void main() => runApp(new SignUp());

class SignUp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: new SignUpForm(),
      ),
    );
  }
}