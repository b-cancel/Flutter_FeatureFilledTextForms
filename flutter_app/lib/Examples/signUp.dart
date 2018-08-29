import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
//import 'package:firebase_auth/firebase_auth.dart';

import '../ExtraFeatures/FormHelper.dart';

import 'package:validator/validator.dart';

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

class SignUpForm extends StatefulWidget {
  const SignUpForm({
    Key key,
  }) : super(key: key);

  @override
  SignUpFromState createState() {
    return new SignUpFromState();
  }
}

class SignUpFromState extends State<SignUpForm> {
  //-------------------------Parameters-------------------------

  //-----form params

  final formKey = new GlobalKey<FormState>();
  final emptyFocusNode = new FocusNode();
  FormData formData;

  //-----form field params

  Map<FocusNode, WrappedString> focusNodeToValue;
  Map<FocusNode, ValueNotifier<String>> focusNodeToError;
  Map<FocusNode, ValueNotifier<bool>> focusNodeToClearIsPossible;
  Map<FocusNode, TextEditingController> focusNodeToController;

  //-----per field params

  final FocusNode emailFocusNode = new FocusNode();
  final FocusNode passwordFocusNode = new FocusNode();
  final FocusNode confirmPasswordFocusNode = new FocusNode();

  //-----extra params

  bool showPassword = false;
  bool showConfirmPassword = false;

  //-------------------------Overrides-------------------------

  @override
  void initState() {
    //-----Manual Variable Init

    List<FocusNode> focusNodes = new List<FocusNode>();
    focusNodes.add(emailFocusNode);
    focusNodes.add(passwordFocusNode);
    focusNodes.add(confirmPasswordFocusNode);

    List<Function> errorRetrievers = new List<Function>();
    errorRetrievers.add(getEmailValidationError);
    errorRetrievers.add(getFirstPasswordValidationError);
    errorRetrievers.add(getSecondPasswordValidationError);

    //-----Automatic Variable Init

    focusNodeToValue = new Map<FocusNode, WrappedString>();
    focusNodeToError = new Map<FocusNode, ValueNotifier<String>>();
    focusNodeToClearIsPossible = new Map<FocusNode, ValueNotifier<bool>>();
    focusNodeToController = new Map<FocusNode, TextEditingController>();
    Map<FocusNode, Function> focusNodeToErrorRetrievers =
    new Map<FocusNode, Function>();
    for (int nodeID = 0; nodeID < focusNodes.length; nodeID++) {
      focusNodeToValue[focusNodes[nodeID]] =
      new WrappedString(""); //this SHOULD NOT start off as null
      focusNodeToError[focusNodes[nodeID]] =
      new ValueNotifier<String>(null); //this SHOULD start off as null
      focusNodeToClearIsPossible[focusNodes[nodeID]] =
      new ValueNotifier<bool>(false);
      focusNodeToController[focusNodes[nodeID]] = new TextEditingController();
      focusNodeToErrorRetrievers[focusNodes[nodeID]] = errorRetrievers[nodeID];
    }

    //-----Form Data To Make Using Form Helper Easier

    formData = new FormData(
      context: context,
      emptyFocusNode: emptyFocusNode,
      submitForm: submitForm,
      focusNodes: focusNodes,
      focusNodeToError: focusNodeToError,
      focusNodeToErrorRetrievers: focusNodeToErrorRetrievers,
      focusNodeToClearIsPossible: focusNodeToClearIsPossible,
      focusNodeToController: focusNodeToController,
      focusNodeToValue: focusNodeToValue,
    );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FormHelper(
      formKey: formKey,
      formData: formData,
      focusNodeForInitialFocus: emailFocusNode,
      child: new Container(
        padding: EdgeInsets.all(16.0),
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            new FlutterLogo(
              size: 250.0,
            ),
            new Form(
              key: formKey,
              child: new Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  emailField(context),
                  passwordField(context),
                  confirmPasswordField(context),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: new Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        new FlatButton(
                          padding: EdgeInsets.all(0.0),
                          onPressed: () {
                            Scaffold.of(context).showSnackBar(
                              SnackBar(
                                  content: new Text("Go To Login Page")),
                            );
                          },
                          child: new Text("Already Have An Account?"),
                        ),
                      ],
                    ),
                  ),
                  new Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      signUpButton(context),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //-------------------------Extracted Widgets-------------------------

  Widget emailField(BuildContext context) {
    return TextFormFieldHelper(
      formData: formData,
      focusNode: emailFocusNode,
      clearIsPossible: focusNodeToClearIsPossible[emailFocusNode],
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
        child: new AnimatedBuilder(
          animation: focusNodeToClearIsPossible[emailFocusNode],
          builder: (context, child) {
            return new AnimatedBuilder(
              animation: focusNodeToError[emailFocusNode],
              builder: (context, child) {
                ensureVisible(context, emailFocusNode);
                return new TextFormField(
                  controller: focusNodeToController[emailFocusNode],
                  focusNode: emailFocusNode,
                  decoration: new InputDecoration(
                    labelText: "Email",
                    hintText: 'you@swol.com',
                    errorText: focusNodeToError[emailFocusNode].value,
                    prefixIcon: Container(
                      padding: EdgeInsets.only(right: 16.0),
                      child: new Icon(Icons.mail),
                    ),
                    suffixIcon:
                    (focusNodeToClearIsPossible[emailFocusNode].value)
                        ? new GestureDetector(
                      onTap: () => clearField(formData, emailFocusNode),
                      child: new Icon(Icons.close),
                    )
                        : new Text(""),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onSaved: (value) => saveField(focusNodeToValue[emailFocusNode], value),
                  onFieldSubmitted: (value) => defaultSubmitField(formData, emailFocusNode, value, true),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget passwordField(BuildContext context) {
    return TextFormFieldHelper(
      formData: formData,
      focusNode: passwordFocusNode,
      clearIsPossible: focusNodeToClearIsPossible[passwordFocusNode],
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
        child: new AnimatedBuilder(
          animation: focusNodeToClearIsPossible[passwordFocusNode],
          builder: (context, child) {
            return new AnimatedBuilder(
              animation: focusNodeToError[passwordFocusNode],
              builder: (context, child) {
                ensureVisible(context, passwordFocusNode);
                return new TextFormField(
                  controller: focusNodeToController[passwordFocusNode],
                  focusNode: passwordFocusNode,
                  decoration: new InputDecoration(
                    labelText: "Password",
                    errorText: focusNodeToError[passwordFocusNode].value,
                    prefixIcon: Container(
                      padding: EdgeInsets.only(right: 16.0),
                      child: new Icon(Icons.security),
                    ),
                    suffixIcon: new Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        (focusNodeToClearIsPossible[passwordFocusNode].value)
                            ? new GestureDetector(
                          onTap: () => clearField(formData, passwordFocusNode),
                          child: new Icon(Icons.close),
                        )
                            : new Text(""),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              showPassword = !showPassword;
                            });
                          },
                          child: new Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: (showPassword)
                                ? new Icon(
                              Icons.lock_open,
                              color: Theme.of(context).hintColor,
                            )
                                : new Icon(
                              Icons.lock_outline,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  obscureText: (showPassword) ? false : true,
                  onSaved: (value) =>
                      saveField(focusNodeToValue[passwordFocusNode], value),
                  onFieldSubmitted: (value) => defaultSubmitField(formData, passwordFocusNode, value, true),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget confirmPasswordField(BuildContext context) {
    return TextFormFieldHelper(
      formData: formData,
      focusNode: confirmPasswordFocusNode,
      clearIsPossible: focusNodeToClearIsPossible[confirmPasswordFocusNode],
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
        child: new AnimatedBuilder(
          animation: focusNodeToClearIsPossible[confirmPasswordFocusNode],
          builder: (context, builder) {
            return new AnimatedBuilder(
              animation: focusNodeToError[confirmPasswordFocusNode],
              builder: (context, child) {
                ensureVisible(context, confirmPasswordFocusNode);
                return new TextFormField(
                  controller: focusNodeToController[confirmPasswordFocusNode],
                  focusNode: confirmPasswordFocusNode,
                  decoration: new InputDecoration(
                    labelText: "Confirm Password",
                    errorText: focusNodeToError[confirmPasswordFocusNode].value,
                    prefixIcon: Container(
                        padding: EdgeInsets.only(right: 16.0),
                        child: new Icon(Icons.security)),
                    suffixIcon: new Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        (focusNodeToClearIsPossible[confirmPasswordFocusNode].value)
                            ? new GestureDetector(
                          onTap: () => clearField(formData, confirmPasswordFocusNode),
                          child: new Icon(Icons.close),
                        )
                            : new Text(""),

                        GestureDetector(
                          onTap: () {
                            setState(() {
                              showConfirmPassword = !showConfirmPassword;
                            });
                          },
                          child: new Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: (showConfirmPassword)
                                ? new Icon(
                              Icons.lock_open,
                              color: Theme.of(context).hintColor,
                            )
                                : new Icon(
                              Icons.lock_outline,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  obscureText: (showConfirmPassword) ? false : true,
                  onSaved: (value) => saveField(focusNodeToValue[confirmPasswordFocusNode], value),
                  onFieldSubmitted: (value) => defaultSubmitField(formData, confirmPasswordFocusNode, value, true),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget signUpButton(BuildContext context) {
    return new RaisedButton(
      onPressed: () => refocus(
        formData,
        new RefocusSettings(
          validationScheme: ValidationScheme.validateAllThenRefocus,
        ),
      ),
      child: new Text("SIGN UP"),
    );
  }

  //-------------------------Per Field Functions-------------------------

  String getEmailValidationError(){
    if(focusNodeToValue[emailFocusNode].value.isNotEmpty == false) return "Email Required";
    else if(isEmail(focusNodeToValue[emailFocusNode].value) != true) return "Valid Email Required";
    else return null;
  }

  String getPasswordValidationError(bool firstPass){
    String firstPassword = focusNodeToValue[passwordFocusNode].value;
    String secondPassword = focusNodeToValue[confirmPasswordFocusNode].value;

    //make sure this particular password is valid
    if(firstPass){
      if(focusNodeToValue[passwordFocusNode].value.isNotEmpty == false) return "Password Required";
      else if(focusNodeToValue[passwordFocusNode].value.length < 6) return "The Password Requires 6 Characters Or More";
    }
    else{
      if(focusNodeToValue[confirmPasswordFocusNode].value.isNotEmpty == false) return "Password Required";
      else if(focusNodeToValue[confirmPasswordFocusNode].value.length < 6) return "The Password Requires 6 Characters Or More";
    }

    //make sure both passwords are valid together
    if(firstPassword.isNotEmpty && secondPassword.isNotEmpty){
      if(firstPassword != secondPassword) return "The Passwords Don't Match";
      else return null;
    }
    else return null;
  }

  String getFirstPasswordValidationError() => getPasswordValidationError(true);
  String getSecondPasswordValidationError() => getPasswordValidationError(false);

  //-------------------------Form Functions-------------------------

  submitForm(bool fieldsValidated) async {
    if (fieldsValidated) {
      Scaffold.of(context).showSnackBar(
        SnackBar(
            content: new Text("Uncomment FireBase Integration Once Ready")),
      );
      /*
      try {
        FirebaseUser user =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: focusNodeToValue[emailFocusNode].string,
          password: focusNodeToValue[passwordFocusNode].string,
        );
        Scaffold.of(context).showSnackBar(
          SnackBar(content: new Text("User ${user.uid} Is Signed In")),
        );
      } catch (e) {
        Scaffold.of(context).showSnackBar(
          SnackBar(content: new Text("Sign In Error $e")),
        );
      }
      */
    }
  }
}