import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
//import 'package:firebase_auth/firebase_auth.dart';

import '../ExtraFeatures/FormHelper.dart';
import '../ExtraFeatures/EnsureVisible.dart';

import 'package:validator/validator.dart';

/// Potential Optimizations:
///   [*] instead of using a "TextInputFormatter" to detect when a key is touched and then refocus

/// Note:
///   [*] The extraction of both animated builders into some easy to use wrapper class or function did not work (for reasons unknown)
///   [*] The "formKey" is required
///       IF "generateListenerFunctions" = true in the "FormHelper"
///   [*] The "emptyFocusNode" is required in "formData"
///       IF "unFocusAllWhenTappingOutside" = true in the "FormHelper"
///   [*] The "formData" and everything it requires, is required
///       IF you want to use anything in "FormHelper"
///   [*] A focusNode is required for each field
///       IF you want to use "FormHelper" or "EnsureVisibleWhenFocused"
///   [*] A custom "getValidationError" function is required for each field
///       IF you want error detection
///       IF the field is Optional then simply have its Error always return null (or valid)
///   [*] The "focusNodeToError" is required
///       IF you want error detection
///   [*] The "focusNodeToValue" is required
///       TO add basic functionality that integrates with both "FormHelper" and "EnsureVisibleWhenFocused"
///   [*] "FormHelper" should cover all the elements on screen
///       IF you want "unFocusAllWhenTappingOutside" to work
///   [*] The "Form" should be wrapped by a "SingleChildScrollView" somewhere above in the widget tree
///       IF you want "EnsureVisibleWhenFocused" to work
///   [*] Every "TextFormField" should be wrapped by a single "EnsureVisibleWhenFocused" somewhere above in the widget tree
///       IF you want "EnsureVisibleWhenFocused" to work
///   [*] The "TextFormField" should be wrapped by a single "AnimatedBuilder" that triggers a rebuild if focusNodeToError[theFieldsFocusNodeHere] changes
///       IF you want Errors to be visually shown when they are detected
///   [*] You need to run "ensureErrorVisible(context: context, focusNode: theFieldsFocusNodeHere);" before the "AnimatedBuilder" returns the "TextFormField"
///       If you want ensure Errors are visible when they come up
///   [*] "<TextInputFormatter> [KeyboardListener(context: context, focusNode: theFieldsFocusNodeHere)]" is required on each "TextFormField"
///        If you want to make sure that the user can see the field they are typing in if they scroll away from it while still focused on it
///   [*] "onSaved: (value) => saveField(focusNodeToValue[theFieldsFocusNodeHere], value)" is required on each "TextFormField"
///        To add basic functionality that integrates with both "FormHelper" and "EnsureVisibleWhenFocused"
///   [*] "onFieldSubmitted" must "saveField(focusNodeToValue[theFieldsFocusNodeHere], value);" before running any other code from "TextFromHelper"
///       To add basic functionality that integrates with both "FormHelper" and "EnsureVisibleWhenFocused"
///   [*] wherever "RefocusSettings" are required you can pass your own custom settings or the defaults
///       every time you call a function that requires this you can have different settings
///       although its suggested that they all be the same, at least when used in "TextFormFields"

class SignIn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: new SignInForm(),
      ),
    );
  }
}

class SignInForm extends StatefulWidget {
  const SignInForm({
    Key key,
  }) : super(key: key);

  @override
  SignInFormState createState() {
    return new SignInFormState();
  }
}

class SignInFormState extends State<SignInForm> {

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

  //-----extra params

  bool showPassword = false;

  //-------------------------Overrides-------------------------

  @override
  void initState() {

    //-----Manual Variable Init

    List<FocusNode> focusNodes = new List<FocusNode>();
    focusNodes.add(emailFocusNode);
    focusNodes.add(passwordFocusNode);

    List<Function> errorRetrievers = new List<Function>();
    errorRetrievers.add(getEmailValidationError);
    errorRetrievers.add(getPasswordValidationError);

    //-----Automatic Variable Init

    focusNodeToValue = new Map<FocusNode, WrappedString>();
    focusNodeToError = new Map<FocusNode, ValueNotifier<String>>();
    focusNodeToClearIsPossible = new Map<FocusNode, ValueNotifier<bool>>();
    focusNodeToController = new Map<FocusNode, TextEditingController>();
    Map<FocusNode, Function> focusNodeToErrorRetrievers = new Map<FocusNode, Function>();
    for(int nodeID = 0; nodeID < focusNodes.length; nodeID++){
      focusNodeToValue[focusNodes[nodeID]] = new WrappedString(""); //this SHOULD NOT start off as null
      focusNodeToError[focusNodes[nodeID]] = new ValueNotifier<String>(null); //this SHOULD start off as null
      focusNodeToClearIsPossible[focusNodes[nodeID]] = new ValueNotifier<bool>(false);
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
      child: new SingleChildScrollView(
        child: new Container(
          padding: EdgeInsets.all(16.0),
          child: new Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              new FlutterLogo(
                size: 350.0,
              ),
              new Form(
                key: formKey,
                child: new Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    fieldBoilerplate(
                      formData,
                      emailFocusNode,
                      (context, child){
                        ensureVisible(context, emailFocusNode);
                        return emailField(context);
                      },
                    ),
                    fieldBoilerplate(
                      formData,
                      passwordFocusNode,
                      (context, child){
                        ensureVisible(context, passwordFocusNode);
                        return passwordField(context);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: new Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          new FlatButton(
                            padding: EdgeInsets.all(0.0),
                            onPressed: (){
                              Scaffold.of(context).showSnackBar(
                                SnackBar(content: new Text("Navigate To Password Reset Page")),
                              );
                            },
                            child: new Text("Forgot Password?"),
                          ),
                          new FlatButton(
                            padding: EdgeInsets.all(0.0),
                            onPressed: (){
                              Scaffold.of(context).showSnackBar(
                                SnackBar(content: new Text("Navigate To Create An Account Page")),
                              );
                            },
                            child: new Text("Create Account"),
                          ),
                        ],
                      ),
                    ),
                    new Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        signInButton(context),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: new TextFormField(
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
          suffixIcon: (focusNodeToClearIsPossible[emailFocusNode].value)
              ? new GestureDetector(
            onTap: () => clearField(formData, emailFocusNode),
            child: new Icon(Icons.close),
          )
              : new Text(""),
        ),
        keyboardType: TextInputType.emailAddress,
        inputFormatters: <TextInputFormatter> [KeyboardListener(context, emailFocusNode)],
        onSaved: (value) => saveField(focusNodeToValue[emailFocusNode], value),
        onFieldSubmitted: (value) => defaultSubmitField(formData, emailFocusNode, value, true),
      ),
    );
  }

  Widget passwordField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: new TextFormField(
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
        inputFormatters: <TextInputFormatter> [KeyboardListener(context, passwordFocusNode)],
        onSaved: (value) => saveField(focusNodeToValue[passwordFocusNode], value),
        onFieldSubmitted: (value) => defaultSubmitField(formData, passwordFocusNode, value, true),
      ),
    );
  }

  Widget signInButton(BuildContext context) {
    return new RaisedButton(
      onPressed: () => refocus(
        formData,
        new RefocusSettings( validationScheme: ValidationScheme.validateAllThenRefocus ),
      ),
      child: new Text("SIGN IN"),
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

  //-------------------------Form Functions-------------------------

  submitForm(bool fieldsValidated) async{
    if(fieldsValidated){
      Scaffold.of(context).showSnackBar(
        SnackBar(content: new Text("Uncomment FireBase Integration Once Ready")),
      );
      /*
      try {
        FirebaseUser user =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
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