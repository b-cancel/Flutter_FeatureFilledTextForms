import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Notes:
///   - some features require some specific parameters
///     * because there are so many features that you can currently switch on and off, I have not required any parameters for the sake of release and testing (by yall)
///     * so you must manually make sure you have all the parameters that you require for the features you desire to use
///     * I will try to specify which parameters are required under what conditions soon but if you would like to help me that would be great
///   - some functions are async (and/or/xor) wait Duration.zero so that things can be scheduled properly
///     * "initFocus" needs this so that after build from your form runs and everything in the FormHelper is setup, then you are able to do a scrolling focus on your desired node TODO...
///     * "listenForFocusNodeChanges" TODO...
///     * "ensureVisible" only needs to be async so that when its called INIT or ON ERROR DETECTED TODO...
///     * "focusField" TODO...
///   - Animated Builders only rebuild if the value changes, if it was set to the exact same value it had before it is not considered a change
///     * this simplifies the code a bit

///   - "ensureVisible" must be called from within a "FormHelper"
///     * this is because it has a "SingleChildScrollView"
///     * it having this means that "RenderAbstractViewport.of(object)" will have [RenderAbstractViewport] as an ancestor
///     * which means that ensureVisible will work

///-------------------------Form Helper Widget-------------------------

enum FocusType {focusAndOpenKeyboard, focusAndCloseKeyboard, focusAndLeaveKeyboard}

class FormHelper extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final FormData formData;
  final RefocusSettings refocusSettings;
  final Widget child;
  final bool generateFocusNodeListenerFunctions;
  final FocusNode focusNodeForInitialFocus;
  final FocusType focusTypeForInitialFocus;
  final bool unFocusAllWhenTappingOutside;

  FormHelper({
    this.formKey,
    this.formData,
    this.refocusSettings,
    this.child,
    this.generateFocusNodeListenerFunctions: true,
    this.unFocusAllWhenTappingOutside: true,
    this.focusNodeForInitialFocus,
    this.focusTypeForInitialFocus: FocusType.focusAndLeaveKeyboard,
  });

  @override
  _FormHelperState createState() => _FormHelperState();
}

class _FormHelperState extends State<FormHelper> {
  List<Function> focusNodeListenerFunctions;

  @override
  void initState() {

    //generate focusNode listener functions, place them as listeners
    if(widget.generateFocusNodeListenerFunctions){
      focusNodeListenerFunctions = new List<Function>();
      for (int i = 0; i < widget.formData.focusNodes.length; i++) {
        FocusNode focusNode = widget.formData.focusNodes[i];
        focusNodeListenerFunctions.add(() {
          if (focusNode.hasFocus == false) {
            widget.formKey.currentState.save();
            validateField(widget.formData, focusNode);
          }
        });
        widget.formData.focusNodes[i].addListener(focusNodeListenerFunctions[i]);
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
      FocusNode focusNode = widget.formData.focusNodes[i];
      if(widget.generateFocusNodeListenerFunctions) focusNode.removeListener(focusNodeListenerFunctions[i]);
      widget.formData.focusNodes[i].dispose();
    }
    if(widget.unFocusAllWhenTappingOutside) widget.formData.emptyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: GestureDetector(
        onTap: () {
          if(widget.unFocusAllWhenTappingOutside) FocusScope.of(context).requestFocus(widget.formData.emptyFocusNode);
        },
        child: widget.child,
      ),
    );
  }
}

///-------------------------Form Helper Functions-------------------------

///NOTE: this is only how most people would want to submit their field, you might want different refocus settings per submission
defaultSubmitField(FormData formData, FocusNode focusNode, String newValue, bool refocusAfter){
  saveField(formData.focusNodeToValue[focusNode], newValue);
  if(refocusAfter) refocus(formData, new RefocusSettings(firstTargetIndex: formData.focusNodes.indexOf(focusNode)));
}

clearField(FormData formData, FocusNode focusNode){
  saveField(formData.focusNodeToValue[focusNode], "");
  formData.focusNodeToController[focusNode].clear();
  formData.focusNodeToValue[focusNode].value = "";
}

saveField(ValueNotifier<String> value, String newValue) => value.value = newValue;

focusField(BuildContext context, FocusNode focusNode, {FocusType focusType: FocusType.focusAndOpenKeyboard}) async{
  FocusScope.of(context).requestFocus(focusNode);
  if(focusType != FocusType.focusAndLeaveKeyboard){
    if(focusType == FocusType.focusAndOpenKeyboard) SystemChannels.textInput.invokeMethod('TextInput.show');
    else SystemChannels.textInput.invokeMethod('TextInput.hide');
  }
}

String validateField(FormData formData, FocusNode focusNode){
  //null error is no error (but still must be displayed to make error go away)
  String errorRetrieved = formData.focusNodeToErrorRetrievers[focusNode]();
  print("validating field");
  formData.focusNodeToError[focusNode].value = errorRetrieved;
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
  while(1==1){ ///Condition too complex to nicely show here, so I create and infinite loop, and use breaks instead

    //process data for this index
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

int _getIndexAfter(int currIndex, int maxIndex){
  currIndex++;
  return (currIndex > maxIndex) ? 0 : currIndex;
}

int _getIndexBefore(int currIndex, int maxIndex){
  currIndex--;
  return (currIndex < 0) ? maxIndex : currIndex;
}

///-------------------------Text Form Field Helper Widget-------------------------

class TextFormFieldHelper extends StatefulWidget {

  final FocusNode focusNode;
  final FormData formData;
  final TransitionBuilder builder;

  final Duration keyboardWait;
  final Duration scrollDuration;
  final Curve scrollCurve;
  final bool ensureVisibleOnFieldFocus;
  final bool ensureVisibleOnReOpenKeyboard;
  final bool ensureVisibleOnKeyboardType;

  //final bool rebuildWidgetOnFieldContentChangeBetweenNoContentAndSomeContent; //TODO make sure this is only used for displaying our clear field button
  //final bool rebuildWidgetOnFieldFocusNodeChange; //TODO check if this is only used for displyaing our clear field button
  //final bool rebuildWidgetOnFieldErrorChange;

  const TextFormFieldHelper({
    this.focusNode,
    this.formData,
    this.builder,

    this.keyboardWait: const Duration(milliseconds: 50), //.05 seconds = 50 milliseconds
    this.scrollDuration: const Duration(milliseconds: 100),
    this.scrollCurve: Curves.ease,
    this.ensureVisibleOnFieldFocus: true,
    this.ensureVisibleOnReOpenKeyboard: true,
    this.ensureVisibleOnKeyboardType: true,

    //this.rebuildWidgetOnFieldContentChangeBetweenNoContentAndSomeContent: true,
    //this.rebuildWidgetOnFieldFocusNodeChange: true,
    //this.rebuildWidgetOnFieldErrorChange: true,
  });

  @override
  _TextFormFieldHelperState createState() => new _TextFormFieldHelperState();
}

class _TextFormFieldHelperState extends State<TextFormFieldHelper> with WidgetsBindingObserver  {

  Function trueWhenTextInField;

  @override
  void initState(){
    super.initState();
    if(widget.ensureVisibleOnReOpenKeyboard) WidgetsBinding.instance.addObserver(this);
    else{
      if(widget.ensureVisibleOnFieldFocus) widget.focusNode.addListener(waitForKeyboardToOpenAndEnsureVisible);
    }
    if(widget.ensureVisibleOnKeyboardType && widget.formData.focusNodeToController[widget.focusNode] != null){
      widget.formData.focusNodeToController[widget.focusNode].addListener(waitForKeyboardToOpenAndEnsureVisible);
    }
    if(widget.formData.focusNodeToTextInField[widget.focusNode] != null && widget.formData.focusNodeToController[widget.focusNode] != null){
      trueWhenTextInField = (){
        if((widget.formData.focusNodeToController[widget.focusNode].text.length ?? 0) > 0) widget.formData.focusNodeToTextInField[widget.focusNode].value = true;
        else widget.formData.focusNodeToTextInField[widget.focusNode].value = false;
      };
      widget.formData.focusNodeToController[widget.focusNode].addListener(trueWhenTextInField);
    }
  }

  @override
  void dispose(){
    if(widget.ensureVisibleOnReOpenKeyboard) WidgetsBinding.instance.removeObserver(this);
    else{
      if(widget.ensureVisibleOnFieldFocus) widget.focusNode.removeListener(waitForKeyboardToOpenAndEnsureVisible);
    }
    if(widget.ensureVisibleOnKeyboardType && widget.formData.focusNodeToController[widget.focusNode] != null) {
      widget.formData.focusNodeToController[widget.focusNode].removeListener(waitForKeyboardToOpenAndEnsureVisible);
    }
    if(widget.formData.focusNodeToTextInField[widget.focusNode] != null && widget.formData.focusNodeToController[widget.focusNode] != null){
      widget.formData.focusNodeToController[widget.focusNode].removeListener(trueWhenTextInField);
    }
    super.dispose();
  }

  @override
  void didChangeMetrics(){
    if(widget.ensureVisibleOnReOpenKeyboard && widget.focusNode.hasFocus) waitForKeyboardToOpenAndEnsureVisible();
  }

  Future<Null> waitForKeyboardToOpenAndEnsureVisible() async {
    // Wait for the keyboard to come into view (if it isn't in view already)
    if(MediaQuery.of(context).viewInsets == EdgeInsets.zero) await waitForKeyboardToOpen();
    // ensure our focusNode is visible
    ensureVisible(context, widget.focusNode, duration: widget.scrollDuration, curve: widget.scrollCurve);
  }

  Future<Null> waitForKeyboardToOpen() async {
    if (mounted){
      EdgeInsets closedInsets = MediaQuery.of(context).viewInsets;
      //this works because MediaQuery.of(context).viewInsets only changes ONCE when the keyboard is FULLY open
      while (mounted && MediaQuery.of(context).viewInsets == closedInsets) {
        await new Future.delayed(widget.keyboardWait);
      }
    }
    return;
  }

  @override
  Widget build(BuildContext context) {
    return new AnimatedBuilder(
      animation: widget.formData.focusNodeToTextInField[widget.focusNode],
      builder: (context, child) {
        return new AnimatedBuilder(
          animation: widget.formData.focusNodeToError[widget.focusNode],
          builder: (context, child) {
            ensureVisible(context, widget.focusNode);
            return new AnimatedBuilder(
              animation: widget.focusNode,
              builder: widget.builder,
            );
          },
        );
      },
    );
  }

  ensureVisible(BuildContext context, FocusNode focusNode, {Duration duration: const Duration(milliseconds: 100), Curve curve: Curves.ease}) async{
    // No need to go any further if the node has not the focus
    if (focusNode.hasFocus){
      final RenderObject object = context.findRenderObject();
      assert(object != null);

      final RenderAbstractViewport viewport = RenderAbstractViewport.of(object);
      assert(viewport != null);

      ScrollableState scrollableState = Scrollable.of(context);
      assert(scrollableState != null);

      // Get its offset
      ScrollPosition position = scrollableState.position;
      double alignment;

      if (position.pixels > viewport.getOffsetToReveal(object, 0.0)) {
        // Move down to the top of the viewport
        alignment = 0.0;
      } else if (position.pixels < viewport.getOffsetToReveal(object, 1.0)){
        // Move up to the bottom of the viewport
        alignment = 1.0;
      }

      if(alignment != null){
        position.ensureVisible(
          object,
          alignment: alignment,
          duration: duration,
          curve: curve,
        );
      }
    }
  }
}

///-------------------------Form Helper Classes-------------------------

class FormData{
  final BuildContext context;
  final FocusNode emptyFocusNode;
  final Function submitForm;
  final List<FocusNode> focusNodes;
  final Map<FocusNode, ValueNotifier<String>> focusNodeToError;
  final Map<FocusNode, Function> focusNodeToErrorRetrievers;
  final Map<FocusNode, TextEditingController> focusNodeToController;
  final Map<FocusNode, ValueNotifier<String>> focusNodeToValue;
  final Map<FocusNode, ValueNotifier<bool>> focusNodeToTextInField;

  FormData({
    this.context,
    this.emptyFocusNode,
    this.submitForm,
    this.focusNodes,
    this.focusNodeToError,
    this.focusNodeToErrorRetrievers,
    this.focusNodeToController,
    this.focusNodeToValue,
    this.focusNodeToTextInField,
  });
}

enum ValidationScheme {validateAllThenRefocus, validateUntilRefocus}
enum ValidationType {check, checkAndShow}
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