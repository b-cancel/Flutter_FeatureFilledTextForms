import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
//import 'package:firebase_auth/firebase_auth.dart';

import '../ExtraFeatures/EnsureVisible.dart';
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
    errorRetrievers.add(getPasswordValidationError);
    errorRetrievers.add(getConfirmPasswordValidationError);

    //-----Automatic Variable Init

    focusNodeToValue = new Map<FocusNode, WrappedString>();
    focusNodeToError = new Map<FocusNode, ValueNotifier<String>>();
    Map<FocusNode, Function> focusNodeToErrorRetrievers = new Map<FocusNode, Function>();
    for(int nodeID = 0; nodeID < focusNodes.length; nodeID++){
      focusNodeToValue[focusNodes[nodeID]] = new WrappedString(""); //this SHOULD NOT start off as null
      focusNodeToError[focusNodes[nodeID]] = new ValueNotifier<String>(null); //this SHOULD start off as null
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
    );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FormHelper(
      formKey: formKey,
      formData: formData,
      focusNodeForInitialFocus: emailFocusNode,
      child: new SingleChildScrollView(
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
                            onPressed: (){
                              Scaffold.of(context).showSnackBar(
                                SnackBar(content: new Text("Go To Login Page")),
                              );
                              //Navigator.of(context).pushReplacementNamed('/signUp')
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
      ),
    );
  }

  //-------------------------Extracted Widgets-------------------------

  Widget emailField(BuildContext context) {
    return new AnimatedBuilder(
      animation: focusNodeToError[emailFocusNode],
      builder: (context, child){
        ensureErrorVisible(context, emailFocusNode);
        return EnsureVisible(
          focusNode: emailFocusNode,
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: new TextFormField(
              focusNode: emailFocusNode,
              decoration: new InputDecoration(
                labelText: "Email",
                hintText: 'you@swol.com',
                errorText: focusNodeToError[emailFocusNode].value,
                prefixIcon: Container(
                    padding: EdgeInsets.only(right: 16.0), child: new Icon(Icons.mail)),
              ),
              keyboardType: TextInputType.emailAddress,
              inputFormatters: <TextInputFormatter> [KeyboardListener(context, emailFocusNode)],
              onSaved: (value) => saveField(focusNodeToValue[emailFocusNode], value),
              onFieldSubmitted: (value) {
                saveField(focusNodeToValue[emailFocusNode], value);
                refocus(
                  formData,
                  new RefocusSettings(firstTargetIndex: formData.focusNodes.indexOf(emailFocusNode)),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget passwordField(BuildContext context) {
    return new AnimatedBuilder(
      animation: focusNodeToError[passwordFocusNode],
      builder: (context, child){
        ensureErrorVisible(context, passwordFocusNode);
        return EnsureVisible(
          focusNode: passwordFocusNode,
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: new TextFormField(
              focusNode: passwordFocusNode,
              decoration: new InputDecoration(
                labelText: "Password",
                errorText: focusNodeToError[passwordFocusNode].value,
                prefixIcon: Container(
                    padding: EdgeInsets.only(right: 16.0),
                    child: new Icon(Icons.security)),
                suffixIcon: GestureDetector(
                  onTap: () {
                    setState(() {
                      showPassword = !showPassword;
                    });
                  },
                  child: (showPassword)
                      ? new Icon(Icons.lock_open, color: Theme.of(context).hintColor)
                      : new Icon(Icons.lock_outline,
                      color: Theme.of(context).hintColor),
                ),
              ),
              obscureText: (showPassword) ? false : true,
              inputFormatters: <TextInputFormatter> [KeyboardListener(context, passwordFocusNode)],
              onSaved: (value) => saveField(focusNodeToValue[passwordFocusNode], value),
              onFieldSubmitted: (value) {
                saveField(focusNodeToValue[passwordFocusNode], value);
                refocus(
                  formData,
                  new RefocusSettings(firstTargetIndex: formData.focusNodes.indexOf(passwordFocusNode)),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget confirmPasswordField(BuildContext context) {
    return new AnimatedBuilder(
      animation: focusNodeToError[confirmPasswordFocusNode],
      builder: (context, child){
        ensureErrorVisible(context, confirmPasswordFocusNode);
        return EnsureVisible(
          focusNode: confirmPasswordFocusNode,
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: new TextFormField(
              focusNode: confirmPasswordFocusNode,
              decoration: new InputDecoration(
                labelText: "Confirm Password",
                errorText: focusNodeToError[confirmPasswordFocusNode].value,
                prefixIcon: Container(
                    padding: EdgeInsets.only(right: 16.0),
                    child: new Icon(Icons.security)),
                suffixIcon: GestureDetector(
                  onTap: () {
                    setState(() {
                      showConfirmPassword = !showConfirmPassword;
                    });
                  },
                  child: (showConfirmPassword)
                      ? new Icon(Icons.lock_open, color: Theme.of(context).hintColor)
                      : new Icon(Icons.lock_outline,
                      color: Theme.of(context).hintColor),
                ),
              ),
              obscureText: (showConfirmPassword) ? false : true,
              inputFormatters: <TextInputFormatter> [KeyboardListener(context, confirmPasswordFocusNode)],
              onSaved: (value) => saveField(focusNodeToValue[confirmPasswordFocusNode], value),
              onFieldSubmitted: (value) {
                saveField(focusNodeToValue[confirmPasswordFocusNode], value);
                refocus(
                  formData,
                  new RefocusSettings(firstTargetIndex: formData.focusNodes.indexOf(confirmPasswordFocusNode)),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget signUpButton(BuildContext context) {
    return new RaisedButton(
      onPressed: () => refocus(
        formData,
        new RefocusSettings( validationScheme: ValidationScheme.validateAllThenRefocus ),
      ),
      child: new Text("SIGN UP"),
    );
  }

  //-------------------------Per Field Functions-------------------------

  String getEmailValidationError() {
    return (isEmail(focusNodeToValue[emailFocusNode].string)) ? null : "Requires Valid Email";
  }

  String getPasswordValidationError(){
    //IF empty (i cant use .IsEmpty because it breaks if you string is null)
    String value = focusNodeToValue[passwordFocusNode].string;
    if(value.isNotEmpty == false) return "Requires Valid Password";
    else if(value.length < 6) return "Requires 6 Characters Or More"; ///NOTE: these are minimum requirements for firebase authentication
    else return null;
  }

  String getConfirmPasswordValidationError(){
    if(focusNodeToValue[passwordFocusNode].string == focusNodeToValue[confirmPasswordFocusNode].string) return null;
    else return "The Passwords Don't Match";
  }

  //-------------------------Form Functions-------------------------

  submitForm(bool fieldsValidated) async{
    if(fieldsValidated){
      Scaffold.of(context).showSnackBar(
        SnackBar(content: new Text("Uncomment FireBase Integration Once Ready")),
      );
    }
  }
}