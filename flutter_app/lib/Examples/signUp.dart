import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ExtraFeatures/FormHelper.dart';

import 'package:validator/validator.dart';

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
  FormData formData;
  FormSettings formSettings;

  //-----form field params

  Map<FocusNode, ValueNotifier<String>> focusNodeToValue;
  Map<FocusNode, ValueNotifier<String>> focusNodeToError;
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
    errorRetrievers.add(getInitialPasswordValidationError);
    errorRetrievers.add(getConfirmPasswordValidationError);

    //-----Automatic Variable Init

    focusNodeToValue = new Map<FocusNode, ValueNotifier<String>>();
    focusNodeToError = new Map<FocusNode, ValueNotifier<String>>();
    focusNodeToController = new Map<FocusNode, TextEditingController>();
    Map<FocusNode, ValueNotifier<bool>> focusNodeToTextInField = new Map<FocusNode, ValueNotifier<bool>>();
    Map<FocusNode, Function> focusNodeToErrorRetrievers =
        new Map<FocusNode, Function>();
    for (int nodeID = 0; nodeID < focusNodes.length; nodeID++) {
      focusNodeToValue[focusNodes[nodeID]] =
          new ValueNotifier<String>(""); //this SHOULD NOT start off as null
      focusNodeToError[focusNodes[nodeID]] =
          new ValueNotifier<String>(null); //this SHOULD start off as null
      focusNodeToController[focusNodes[nodeID]] = new TextEditingController();
      focusNodeToTextInField[focusNodes[nodeID]] =
          new ValueNotifier<bool>(false);
      focusNodeToErrorRetrievers[focusNodes[nodeID]] = errorRetrievers[nodeID];
    }

    //-----Form Data and Form Settings => to Make Using The Form Helper Easier

    formData = new FormData(
      formKey: formKey,
      context: context,
      submitForm: submitForm,
      focusNodes: focusNodes,
      focusNodeToError: focusNodeToError,
      focusNodeToErrorRetrievers: focusNodeToErrorRetrievers,
      focusNodeToController: focusNodeToController,
      focusNodeToValue: focusNodeToValue,
      focusNodeToTextInField: focusNodeToTextInField,
    );

    formSettings = new FormSettings();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FormHelper(
      formData: formData,
      formSettings: formSettings,
      focusNodeForInitialFocus: confirmPasswordFocusNode,
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
      formSettings: formSettings,
      focusNode: emailFocusNode,
      builder: (context, child) {
        return new Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
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
              suffixIcon: clearFieldButton(formData, emailFocusNode, clearFieldButtonAppearOn: formSettings.clearFieldBtnAppearOn),
            ),
            keyboardType: TextInputType.emailAddress,
            onSaved: (value) =>
                saveField(focusNodeToValue[emailFocusNode], value),
            onFieldSubmitted: (value) =>
                defaultSubmitField(formData, emailFocusNode, value, true),
          ),
        );
      },
    );
  }

  Widget passwordField(BuildContext context) {
    return TextFormFieldHelper(
      formData: formData,
      formSettings: formSettings,
      focusNode: passwordFocusNode,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
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
                  clearFieldButton(formData, passwordFocusNode, clearFieldButtonAppearOn: formSettings.clearFieldBtnAppearOn),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        showPassword = !showPassword;
                      });
                    },
                    child: passwordShowHideButton(showPassword, iconColor: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
            obscureText: (showPassword) ? false : true,
            onSaved: (value) =>
                saveField(focusNodeToValue[passwordFocusNode], value),
            onFieldSubmitted: (value) =>
                defaultSubmitField(formData, passwordFocusNode, value, true),
          ),
        );
      },
    );
  }

  Widget confirmPasswordField(BuildContext context) {
    return TextFormFieldHelper(
      formData: formData,
      formSettings: formSettings,
      focusNode: confirmPasswordFocusNode,
      builder: (context, child) {
        return new Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
          child: new TextFormField(
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
                  clearFieldButton(formData, confirmPasswordFocusNode, clearFieldButtonAppearOn: formSettings.clearFieldBtnAppearOn),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        showConfirmPassword = !showConfirmPassword;
                      });
                    },
                    child: passwordShowHideButton(showConfirmPassword, iconColor: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
            obscureText: (showConfirmPassword) ? false : true,
            onSaved: (value) =>
                saveField(focusNodeToValue[confirmPasswordFocusNode], value),
            onFieldSubmitted: (value) => defaultSubmitField(
                formData, confirmPasswordFocusNode, value, true),
          ),
        );
      },
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

  String getEmailValidationError() {
    if (focusNodeToValue[emailFocusNode].value.isNotEmpty == false)
      return "Email Required";
    else if (isEmail(focusNodeToValue[emailFocusNode].value) != true)
      return "Valid Email Required";
    else
      return null;
  }

  String getPasswordValidationError(bool forPassword) {
    String initialPasswordString = focusNodeToValue[passwordFocusNode].value;
    String confirmPasswordString = focusNodeToValue[confirmPasswordFocusNode].value;

    ///-----make sure this particular password is valid
    if (forPassword) {
      if (initialPasswordString.isNotEmpty == false)
        return "Password Required";
      else if (initialPasswordString.length < 6)
        return "The Password Requires 6 Characters Or More";
    } else {
      if (confirmPasswordString.isNotEmpty == false)
        return "Password Required";
      else if (confirmPasswordString.length < 6)
        return "The Password Requires 6 Characters Or More";
    }

    ///-----make sure both passwords are valid together
    if (initialPasswordString.isNotEmpty && confirmPasswordString.isNotEmpty) {
      if (initialPasswordString != confirmPasswordString){
        if(forPassword && focusNodeToError[confirmPasswordFocusNode].value == null){
          focusNodeToError[confirmPasswordFocusNode].value = "The Passwords Don't Match";
        }
        else if(focusNodeToError[passwordFocusNode].value == null){
          focusNodeToError[passwordFocusNode].value = "The Passwords Don't Match";
        }
        return "The Passwords Don't Match";
      }
      else {
        if(forPassword) focusNodeToError[confirmPasswordFocusNode].value = null;
        else focusNodeToError[passwordFocusNode].value = null;

        return null;
      }
    } else {
      return null;
    }
  }

  String getInitialPasswordValidationError() => getPasswordValidationError(true);
  String getConfirmPasswordValidationError() => getPasswordValidationError(false);

  //-------------------------Form Functions-------------------------

  submitForm(bool fieldsValidated) async {
    if (fieldsValidated) {
      Scaffold.of(context).showSnackBar(
        SnackBar(
          content: new Text("Add Create User With Email And Password Functionality Here"),
        ),
      );
    }
  }
}
