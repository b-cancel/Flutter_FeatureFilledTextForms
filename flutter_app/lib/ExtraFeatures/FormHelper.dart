import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Note:
/// [*] some functions are async and wait Duration.zero simply because that schedules them after something else that should happen first for everything to work properly
/// [*] "WrappedString" is used to pass the value of the field by reference so that it can then be updated by external function "saveField"
/// [*] "FormData" helps in passing all the FormData that is required by these external functions
///     only one formData should be used per form
/// [*] "RefocusSettings" passes all the settings to functions that require refocusing
///     multiple varied refocus settings can be used per form
///
/// Definitions:
/// [*] "Scrolling Focus" Refers to the Feature that "EnsureVisibleWhenFocused" adds
///
/// Feature Set [Widget]:
/// [1] Generates Listener Functions and adds one of these to each focus node,
///   this allows each field to be saved and validated when we un focus that field
/// [2] Use "refocusSettings" to refocus on different fields depending on the conditions passed
/// [3] Automatically disposes of the Listeners on each Focus Node, and each Focus Node
/// [4] Allows for Initial Scrolling Focus to one node in "focusNode"
/// [5] UnFocuses All Nodes When Tapping anything that isn't a form field
///   [*] also ends up validating and showing the result of the validation of the focused node because of the Focus Node Listeners on each focus node
///
/// Feature Set [Function]:
/// [1] "focusField" focuses the field and also has options to deal with the keyboard
/// [2] "saveField" saves the information currently in the text field by using a wrapper class, and it's used both "onSaved" and "onFieldSubmitted"
/// [3] "validateField" is used to validate each field with its perspective validation function,
///   and it displays the result of the validation on screen by using a ValueNotifier that detect changes on the error for that field
/// TODO: Improve Both Refocus Functions and RefocusSettings (Everything seems okay now but I have a gut feeling it will require it)
/// [4] "refocusDependingOnValidation" refocuses different depending on the validation error passed
/// [5] "refocus" refocuses onto another field with a myriad of options

///-------------------------Form Helper Widget-------------------------

enum FocusType {focusAndOpenKeyboard, focusAndCloseKeyboard, focusAndLeaveKeyboard}

class FormHelper extends StatefulWidget {
  final GlobalKey<FormState> formKey; /// REQUIRED IF: generateListenerFunctions = true
  final FormData formData;
  final RefocusSettings refocusSettings; /// REQUIRED IF: generateListenerFunctions = true
  final Widget child;
  final bool generateListenerFunctions;
  final FocusNode focusNodeForInitialFocus;
  final FocusType focusTypeForInitialFocus; /// ONLY RELEVANT IF: focusNodeForInitialFocus != null
  final bool unFocusAllWhenTappingOutside;

  FormHelper({
    this.formKey,
    @required this.formData,
    this.refocusSettings,
    @required this.child,
    this.generateListenerFunctions: true,
    this.unFocusAllWhenTappingOutside: true,
    this.focusNodeForInitialFocus,
    this.focusTypeForInitialFocus: FocusType.focusAndLeaveKeyboard,
  });

  @override
  _TextFormHelperState createState() => _TextFormHelperState();
}

class _TextFormHelperState extends State<FormHelper> {
  List<Function> listenerFunctions;

  @override
  void initState() {

    //generate functions, place them as listeners
    if(widget.generateListenerFunctions){
      listenerFunctions = new List<Function>();
      for (int i = 0; i < widget.formData.focusNodes.length; i++) {
        listenerFunctions.add(generateListenerFunction(widget.formData, widget.formData.focusNodes[i]));
        widget.formData.focusNodes[i].addListener(listenerFunctions[i]);
      }
    }

    //autoFocus the first node
    if (widget.focusNodeForInitialFocus != null) initFocus();

    super.initState();
  }

  //the standard "TextFormField" "autoFocus" property doesn't automatically scroll. So we use this instead.
  initFocus() async {
    await Future.delayed(Duration.zero);
    focusField(widget.formData.context, widget.focusNodeForInitialFocus, focusType: widget.focusTypeForInitialFocus);
  }

  @override
  void dispose() {
    for (int i = 0; i < widget.formData.focusNodes.length; i++) {
      if(widget.generateListenerFunctions) widget.formData.focusNodes[i].removeListener(listenerFunctions[i]);
      widget.formData.focusNodes[i].dispose();
    }
    if(widget.unFocusAllWhenTappingOutside) widget.formData.emptyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if(widget.unFocusAllWhenTappingOutside) FocusScope.of(context).requestFocus(widget.formData.emptyFocusNode);
      },
      child: widget.child,
    );
  }

  Function generateListenerFunction(FormData formData, FocusNode focusNode) {
    return () {
      if (focusNode.hasFocus == false) {
        widget.formKey.currentState.save();
        validateField(formData, focusNode);
      }
    };
  }
}

///-------------------------Form Helper Functions-------------------------

focusField(BuildContext context, FocusNode focusNode, {FocusType focusType: FocusType.focusAndOpenKeyboard}) async{
  FocusScope.of(context).requestFocus(focusNode);
  if(focusType != FocusType.focusAndLeaveKeyboard){
    if(focusType == FocusType.focusAndOpenKeyboard) SystemChannels.textInput.invokeMethod('TextInput.show');
    else SystemChannels.textInput.invokeMethod('TextInput.hide');
  }
}

saveField(WrappedString finalDest, String currentDest) => finalDest.string = currentDest;

String validateField(FormData formData, FocusNode focusNode){
  //null error is no error (but still must be displayed to make error go away)
  String errorRetrieved = formData.focusNodeToErrorRetrievers[focusNode]();
  if(errorRetrieved != formData.focusNodeToError[focusNode].value){
    formData.focusNodeToError[focusNode].value = errorRetrieved;
  }
  return errorRetrieved;
}

refocusDependingOnValidation(
    FormData formData,
    String validationResult,
    {RefocusSettings refocusSettingsIfPass,
      RefocusSettings refocusSettingsIfFail,
    }){
  if(validationResult == null) refocus(formData, refocusSettingsIfPass);
  else refocus(formData, refocusSettingsIfFail);
}

refocus(FormData formData, RefocusSettings refocusSettings){
  //variable setup
  FocusNode fieldToFocus;

  //find out what field to refocus on
  int index = refocusSettings.firstTargetIndex;
  while(1==1){ ///Condition too complex to nicely show here, create and infinite loop, and use break instead

    //process data for this indexG
    bool validationPassed = (formData.focusNodeToErrorRetrievers[formData.focusNodes[index]]() == null);

    //if we have yet to find what field we want to focus on... find out if this is it...
    //if it is and we only wanted to validate until this point, stop...
    if(fieldToFocus == null){
      //if (NOT SKIP IF VALID || (SKIP IF VALID && NOT VALID))
      if(refocusSettings.skipTargetIfValidates == false || validationPassed == false){
        fieldToFocus = formData.focusNodes[index];
        if(refocusSettings.validationScheme == ValidationScheme.validateUntilRefocus){
          if(refocusSettings.validationType == ValidationType.checkAndShow && index == refocusSettings.firstTargetIndex){
            //COVERING EXCEPTION
            validateField(formData, formData.focusNodes[index]);
          }
          break; //BREAK CONDITION
        }
      }
    }

    //COVERING EXCEPTION
    //now we actually validate the field depending on [validationType]
    //this is done here because we don't want a field that we have not had the chance to place info into to show an error
    if(refocusSettings.validationType == ValidationType.checkAndShow) validateField(formData, formData.focusNodes[index]);

    //calculate next index && BREAK CONDITIONS
    int maxIndex = formData.focusNodes.length - 1;
    if(refocusSettings.loopSearch == false){
      if(refocusSettings.searchDirection == SearchDirection.topToBottom) index++;
      else index--;
      //BREAK CONDITION
      if(index < 0 || maxIndex < index) break;
    }
    else{
      if(refocusSettings.searchDirection == SearchDirection.topToBottom) index = _getIndexAfter(index , maxIndex);
      else index = _getIndexBefore(index, maxIndex);
      //BREAK CONDITION
      if(index == refocusSettings.firstTargetIndex) break;
    }
  }

  //refocus if we have not yet validated all of our fields
  if(fieldToFocus != null) focusField(formData.context, fieldToFocus, focusType: refocusSettings.focusType);
  else{
    //if we have validated all of our fields check if we can submit our data
    if(refocusSettings.submitFormIfAllValid) formData.submitForm(true);
  }
}

///-------------------------Helper Classes And Functions-------------------------

class WrappedString{
  String string;
  WrappedString(this.string);
}

class FormData{
  final BuildContext context;
  final FocusNode emptyFocusNode;
  final Function submitForm;
  final List<FocusNode> focusNodes;
  final Map<FocusNode, ValueNotifier<String>> focusNodeToError;
  final Map<FocusNode, Function> focusNodeToErrorRetrievers;

  FormData({
    @required this.context,
    this.emptyFocusNode, ///REQUIRED IF: unFocusAllWhenTappingOutside = true
    @required this.submitForm,
    @required this.focusNodes,
    @required this.focusNodeToError,
    @required this.focusNodeToErrorRetrievers,
  });
}

enum ValidationScheme {validateAllThenRefocus, validateUntilRefocus}
enum ValidationType {check, checkAndShow}
enum TargetsAvailable {others, selfOrOthers}
enum SearchDirection {topToBottom, bottomToTop}

class RefocusSettings{
  final ValidationScheme validationScheme;
  final ValidationType validationType;
  final int firstTargetIndex;
  final SearchDirection searchDirection;
  final bool loopSearch;
  final bool skipTargetIfValidates;
  final FocusType focusType;
  final bool submitFormIfAllValid;

  RefocusSettings({
    this.validationScheme: ValidationScheme.validateUntilRefocus,
    this.validationType: ValidationType.checkAndShow,
    this.firstTargetIndex: 0,
    this.searchDirection: SearchDirection.topToBottom,
    this.loopSearch: true,
    this.skipTargetIfValidates: true,
    this.focusType: FocusType.focusAndOpenKeyboard,
    this.submitFormIfAllValid: true,
  });
}

int _getIndexAfter(int currIndex, int maxIndex){
  currIndex++;
  return (currIndex > maxIndex) ? 0 : currIndex;
}

int _getIndexBefore(int currIndex, int maxIndex){
  currIndex--;
  return (currIndex < 0) ? maxIndex : currIndex;
}