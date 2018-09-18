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

enum PasswordChange {show, hide, none}

class SignUpFromState extends State<SignUpForm> {
  //-------------------------Parameters-------------------------

  //-----form params

  final formKey = new GlobalKey<FormState>();
  FormData formData;
  FormSettings formSettings;

  //-----form field params

  Map<FocusNode, ValueNotifier<String>> focusNodeToValue;
  Map<FocusNode, ValueNotifier<String>> focusNodeToHelper;
  Map<FocusNode, ValueNotifier<String>> focusNodeToError;
  Map<FocusNode, TextEditingController> focusNodeToController;

  //-----per field params

  final FocusNode emailFocusNode = new FocusNode();
  final FocusNode passwordFocusNode = new FocusNode();

  //-----extra params

  Map<FocusNode, bool> focusNodeToShowPassword;
  Map<FocusNode, bool> focusNodeToInitialFocus;

  AppearOn clearButtonAppearOn = AppearOn.fieldFocusedAndFieldNotEmpty;
  AppearOn showHidePasswordButtonAppearOn = AppearOn.fieldNotEmpty;

  PasswordChange whenEnterFocus = PasswordChange.show;
  PasswordChange whenExitFocus = PasswordChange.hide;

  //shows in red
  TextToShow textToShowOnError = TextToShow.firstError;
  TextOrder textOrderOnError = TextOrder.BigToLittle;

  //show in grey
  TextToShow textToShowOnHelper = TextToShow.allErrors;
  TextOrder textOrderOnHelper = TextOrder.littleToBig;

  //-------------------------Overrides-------------------------

  @override
  void initState() {
    //-----Manual Variable Init

    focusNodeToShowPassword = new Map<FocusNode, bool>();
    focusNodeToShowPassword[passwordFocusNode] = false;

    focusNodeToInitialFocus = new Map<FocusNode, bool>();
    focusNodeToInitialFocus[passwordFocusNode] = true;

    List<FocusNode> focusNodes = new List<FocusNode>();
    focusNodes.add(emailFocusNode);
    focusNodes.add(passwordFocusNode);

    List<Function> helperRetrievers = new List<Function>();
    helperRetrievers.add((){return getEmailValidationError(textOrderOnHelper, textToShowOnHelper);});
    helperRetrievers.add((){return getPasswordValidationError(textOrderOnHelper, textToShowOnHelper);});

    List<Function> errorRetrievers = new List<Function>();
    errorRetrievers.add((){return getEmailValidationError(textOrderOnError, textToShowOnError);});
    errorRetrievers.add((){return getPasswordValidationError(textOrderOnError, textToShowOnError);});

    //-----Automatic Variable Init

    focusNodeToValue = new Map<FocusNode, ValueNotifier<String>>();
    focusNodeToHelper = new Map<FocusNode, ValueNotifier<String>>();
    focusNodeToError = new Map<FocusNode, ValueNotifier<String>>();
    focusNodeToController = new Map<FocusNode, TextEditingController>();
    Map<FocusNode, ValueNotifier<bool>> focusNodeToTextInField = new Map<FocusNode, ValueNotifier<bool>>();
    ///SUPER IMPORTANT: when you generate you own error retrievers, for everything to work properly you CAN NOT edit the fields from within the function, let the FormHelper do that
    Map<FocusNode, Function> focusNodeToErrorRetrievers = new Map<FocusNode, Function>();
    Map<FocusNode, Function> focusNodeToHelperRetrievers = new Map<FocusNode, Function>();
    for (int nodeID = 0; nodeID < focusNodes.length; nodeID++) {
      focusNodeToValue[focusNodes[nodeID]] =
          new ValueNotifier<String>(""); //this SHOULD NOT start off as null
      focusNodeToHelper[focusNodes[nodeID]] =
          new ValueNotifier<String>(null); //this SHOULD start off as null
      focusNodeToError[focusNodes[nodeID]] =
      new ValueNotifier<String>(null); //this SHOULD start off as null
      focusNodeToController[focusNodes[nodeID]] = new TextEditingController();
      focusNodeToTextInField[focusNodes[nodeID]] =
          new ValueNotifier<bool>(false);
      focusNodeToErrorRetrievers[focusNodes[nodeID]] = errorRetrievers[nodeID];
      focusNodeToHelperRetrievers[focusNodes[nodeID]] = helperRetrievers[nodeID];
    }

    //-----Form Data and Form Settings => to Make Using The Form Helper Easier

    formData = new FormData(
      formKey: formKey,
      context: context,
      submitForm: submitForm,
      focusNodes: focusNodes,
      focusNodeToHelper: focusNodeToHelper,
      focusNodeToError: focusNodeToError,
      focusNodeToHelperRetrievers: focusNodeToHelperRetrievers,
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
            new Container(
              width: 200.0,
              child: new FittedBox(
                fit: BoxFit.fitWidth,
                child: new Text("Sign Up"),
              ),
            ),
            new Form(
              key: formKey,
              child: new Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  emailField(context),
                  passwordField(context),
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
              helperText: focusNodeToHelper[emailFocusNode].value,
              errorText: focusNodeToError[emailFocusNode].value,
              prefixIcon: Container(
                padding: EdgeInsets.only(right: 16.0),
                child: new Icon(Icons.mail),
              ),
              suffixIcon: clearFieldButton(doWeAppear(formData, emailFocusNode, appearOn: clearButtonAppearOn), emailFocusNode),
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
              ///NOTE: If "widget.formSettings.reloadOnFieldContentChange == false" then you will have to find a way to update the counter yourself
              counterText: extraPasswordCounter(focusNodeToController[passwordFocusNode].text.length),
              helperText: focusNodeToHelper[passwordFocusNode].value,
              errorText: focusNodeToError[passwordFocusNode].value,
              prefixIcon: Container(
                padding: EdgeInsets.only(right: 16.0),
                child: new Icon(Icons.security),
              ),
              suffixIcon: new Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  clearFieldButton(doWeAppear(formData, passwordFocusNode, appearOn: clearButtonAppearOn), passwordFocusNode),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        focusNodeToShowPassword[passwordFocusNode] = !focusNodeToShowPassword[passwordFocusNode];
                      });
                    },
                    child: passwordShowHideButton(passwordFocusNode, doWeAppear(formData, passwordFocusNode, appearOn: showHidePasswordButtonAppearOn), Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
            obscureText: (focusNodeToShowPassword[passwordFocusNode]) ? false : true,
            onSaved: (value) =>
                saveField(focusNodeToValue[passwordFocusNode], value),
            onFieldSubmitted: (value) =>
                defaultSubmitField(formData, passwordFocusNode, value, true),
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

  Widget clearFieldButton(bool doWeAppear, FocusNode focusNode){
    if(doWeAppear){
      return new GestureDetector(
        onTap: () =>  clearField(formData, focusNode),
        child: new Icon(Icons.close),
      );
    }
    else return new Text("");
  }

  Widget passwordShowHideButton(FocusNode focusNode, bool doWeAppear, Color iconColor){

    if(focusNode.hasFocus == true){
      if(focusNodeToInitialFocus[focusNode] == true){
        focusNodeToInitialFocus[focusNode] = false;
        if(whenEnterFocus != PasswordChange.none){
          focusNodeToShowPassword[focusNode] = (whenEnterFocus == PasswordChange.show);
        }
      }
    }
    else{
      if(focusNodeToInitialFocus[focusNode] == false){
        focusNodeToInitialFocus[focusNode] = true;
        if(whenExitFocus != PasswordChange.none){
          focusNodeToShowPassword[focusNode] = (whenExitFocus == PasswordChange.show);
        }
      }
    }

    if(doWeAppear){
      return new Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: (focusNodeToShowPassword[focusNode])
            ? new Icon(
          Icons.lock_open,
          color: iconColor,
        )
            : new Icon(
          Icons.lock_outline,
          color: iconColor,
        ),
      );
    }
    else return new Text("");
  }

  //-------------------------Per Field Functions-------------------------

  String getEmailValidationError(TextOrder textOrder, TextToShow textToShow) {
    ///-----generate variables
    String emailString = focusNodeToValue[emailFocusNode].value;
    List<String> errors = new List();

    ///-----grab all the potential errors
    if (emailString.isNotEmpty == false){
      errors.add("Email Required");
    }
    if (isEmail(emailString) != true){
      errors.add("Valid Email Required");
    }

    ///-----generate the string to return
    return generateErrorString(errors, textOrder, textToShow);
  }

  String getPasswordValidationError(TextOrder textOrder, TextToShow textToShow) {
    ///-----generate all the variables
    String passwordString = focusNodeToValue[passwordFocusNode].value;
    List<String> errors = new List();

    ///-----grab all the potential errors (for the individual)
    if (passwordString.isNotEmpty == false){
      errors.add("Password Required");
    }
    if (passwordString.length < 6){
      errors.add("The Password Requires 6 Characters Or More");
    }

    ///-----process all compiled errors
    return generateErrorString(errors, textOrder, textToShow);
  }

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

  //-------------------------Extra Functions-------------------------

  String extraPasswordCounter(int characterCount){
    if(characterCount >= 6) return "";
    else return characterCount.toString() + "/6";
  }
}
