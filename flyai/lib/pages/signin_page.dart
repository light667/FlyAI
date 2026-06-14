import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flyai/pages/loading_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  @override
  void initState() {
    super.initState();
    signIn();
  }

  Future<Timer> signIn() async {
    return Timer(const Duration(seconds: 3), onSignedIn);
  }

  void onSignedIn() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoadingPage(title: 'loading')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}