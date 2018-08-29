import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// New Notes:
///   - some functions are async (and/or/xor) wait Duration.zero so that things can be scheduled properly
///     * "initFocus" needs this so that after build from your form runs and everything in the FormHelper is setup, then you are able to do a scrolling focus on your desired node TODO...
///     * "listenForFocusNodeChanges" TODO...
///     * "ensureVisible" only needs to be async so that when its called INIT or ON ERROR DETECTED TODO...
///     * "focusField" TODO...
///   - "ensureVisible" must be called from within a "FormHelper"
///     * this is because it has a "SingleChildScrollView"
///     * it having this means that "RenderAbstractViewport.of(object)" will have [RenderAbstractViewport] as an ancestor
///     * which means that ensureVisible will work

/// Note:
/// [*] some functions are async simply because that schedules them after something else that should happen first for everything to work properly
/// [*] you really should not use "ensureVisible" or "ensureErrorVisible" or "KeyboardListener" unless that field is already wrapped in "EnsureVisibleWhenFocused"
///     you will get very unusual behavior
///
/// Feature Set:
///   [1] Wrap any field with "EnsureVisibleWhenFocused" if you want that field to be automatically ensure visible on the conditions indicated
///     1. ensure a field is visible when its toggled to focused from unfocused
///     2. ensure a field is visible when the keyboard opens (after being dismissed manually)
///   [2] Wrap any field that is already wrapped with "EnsureVisibleWhenFocused" with an "AnimatedBuilder"
///     that updates when the error in "focusNodeToError" changes to have errors found during validation show up on screen
///   [3] Before you return the main widget in the "AnimatedBuilder" run "ensureErrorVisible" to ensure the error is still in view once it pops up
///   [4] Add a "KeyboardListener" to each field that you want to automatically scroll into focus if the keyboard is tapped
///
/// Other Modifications Written By: Bryan Cancel
///   1. Removed un needed delay that is now covered by checking keyboard metrics
///   2. Added the Code that only makes us wait for the keyboard to be in view IF it isn't already in view
///   3. Made "ensureVisible" an external function that can be accessible by other functions so we can refocus properly on certain edge cases
///     [+] this became relevant with the implementation of per field input validation (instead of validating the form all at once)
///   4. Added "ensureErrorVisible" to simplify the code required to use [3] properly
///     [*] must be async to delay execution and schedule it after the error is built
///   5. Added "KeyboardListener" that can be added as an input formatter in the "TextFormField.inputFormatters" property so that you automatically refocus when typing
///   6. Added "keyboardWait" or the quantity of time before we check if the keyboard is open, If it isn't open we wat that quantity again until it is open
///     [*] this is flexible because it might take some phone keyboards longer to open up
///   7. Function renames
/// Modified Source Code Added By: Peter Yuen
///   1. Makes sure that if the user closes the keyboard, we wait for it to pop up, and then we ensure the field is visible
/// Modified Source Code Added By: boeledi
///   [*] https://www.didierboelens.com/2018/04/hint-4-ensure-a-textfield-or-textformfield-is-visible-in-the-viewport-when-has-the-focus/
///   1. Added code to ensure visible when the metrics change or when the keyboard opens or closes
/// Initial Source Code Written By: Collen Jackson
///   [*] Code Can Be Found At: https://gist.github.com/collinjackson/50172e3547e959cba77e2938f2fe5ff5
///   1. Ensure a field is visible when its focused by scrolling to it

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
  final bool generateFocusNodeListenerFunctions;
  final FocusNode focusNodeForInitialFocus;
  final FocusType focusTypeForInitialFocus; /// ONLY RELEVANT IF: focusNodeForInitialFocus != null
  final bool unFocusAllWhenTappingOutside;

  FormHelper({
    this.formKey,
    @required this.formData,
    this.refocusSettings,
    @required this.child,
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
        focusNodeListenerFunctions.add(generateFocusNodeListenerFunction(widget.formData, focusNode));
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

  Function generateFocusNodeListenerFunction(FormData formData, FocusNode focusNode) {
    return () {
      if (focusNode.hasFocus == false) {
        widget.formKey.currentState.save();
        validateField(formData, focusNode);
      }
    };
  }
}

///-------------------------Form Helper Functions-------------------------

///NOTE: this is only how most people would want to submit their field, you might want different refocus settings per submission
defaultSubmitField(FormData formData, FocusNode focusNode, String newValue, bool refocusAfter){
  saveField(formData.focusNodeToValue[focusNode], newValue);
  if(refocusAfter) refocus(formData, new RefocusSettings(firstTargetIndex: formData.focusNodes.indexOf(focusNode)));
}
clearField(FormData formData, FocusNode focusNode){
  formData.focusNodeToController[focusNode].clear();
  formData.focusNodeToValue[focusNode].value = "";
}

focusField(BuildContext context, FocusNode focusNode, {FocusType focusType: FocusType.focusAndOpenKeyboard}) async{
  FocusScope.of(context).requestFocus(focusNode);
  if(focusType != FocusType.focusAndLeaveKeyboard){
    if(focusType == FocusType.focusAndOpenKeyboard) SystemChannels.textInput.invokeMethod('TextInput.show');
    else SystemChannels.textInput.invokeMethod('TextInput.hide');
  }
}

saveField(WrappedString finalDest, String currentDest) => finalDest.value = currentDest;

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
  String value;
  WrappedString(this.value);
}

class FormData{
  final BuildContext context;
  final FocusNode emptyFocusNode;
  final Function submitForm;
  final List<FocusNode> focusNodes;
  final Map<FocusNode, ValueNotifier<String>> focusNodeToError;
  final Map<FocusNode, Function> focusNodeToErrorRetrievers;
  final Map<FocusNode, ValueNotifier<bool>> focusNodeToClearIsPossible;
  final Map<FocusNode, TextEditingController> focusNodeToController;
  final Map<FocusNode, WrappedString> focusNodeToValue;

  FormData({
    @required this.context,
    this.emptyFocusNode, ///REQUIRED IF: unFocusAllWhenTappingOutside = true
    @required this.submitForm,
    @required this.focusNodes,
    @required this.focusNodeToError,
    @required this.focusNodeToErrorRetrievers,
    @required this.focusNodeToClearIsPossible,
    @required this.focusNodeToController,
    @required this.focusNodeToValue,
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

///-------------------------Ensure Visible Functions-------------------------

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

///-------------------------Other Widget-------------------------

//TODO... duration and curve... for waiting for keyboard AND for type on keyboard... 2 separate ones

class TextFormFieldHelper extends StatefulWidget {

  final FormData formData;
  final FocusNode focusNode;
  final Duration duration; //time it takes us to scroll ourselves into view
  final Curve curve; //the curve we use to scroll ourselves into view
  final Duration keyboardWait; //the time we wait to once again check if the keyboard is finally open
  final ValueNotifier<bool> clearIsPossible; //if we pass this value notifier its implicit that we want this to be true, when the node is focused
  final Widget child;
  final bool generateControllerListenerFunctions;

  const TextFormFieldHelper({
    Key key,
    @required this.formData,
    @required this.focusNode,
    this.duration: const Duration(milliseconds: 100),
    this.curve: Curves.ease,
    //what most humans consider instant is .1 seconds, so we want to check if the keyboard is finally open a little bit more often than that .05 seconds
    this.keyboardWait: const Duration(milliseconds: 50), //.05 seconds = 50 milliseconds
    this.clearIsPossible,
    @required this.child,
    this.generateControllerListenerFunctions: true,
  }) : super(key: key);

  @override
  _EnsureVisibleWhenFocusedState createState() => new _EnsureVisibleWhenFocusedState();
}

class _EnsureVisibleWhenFocusedState extends State<TextFormFieldHelper> with WidgetsBindingObserver  {
  Function controllerListenerFunction;

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.focusNode.addListener(listenForFocusNodeChanges);
    if(widget.generateControllerListenerFunctions){
      controllerListenerFunction = () => ensureVisible(context, widget.focusNode);
      widget.formData.focusNodeToController[widget.focusNode].addListener(controllerListenerFunction);
    }
  }

  @override
  void dispose(){
    WidgetsBinding.instance.removeObserver(this);
    widget.focusNode.removeListener(listenForFocusNodeChanges);
    if(widget.generateControllerListenerFunctions) widget.formData.focusNodeToController[widget.focusNode].removeListener(controllerListenerFunction);
    super.dispose();
  }

  @override
  void didChangeMetrics(){
    if(widget.focusNode.hasFocus) waitForKeyboardToOpenAndEnsureVisible();
  }

  listenForFocusNodeChanges() async{
    //used if you want a clear field option to show up per field only when its focused
    if(widget.clearIsPossible != null) widget.clearIsPossible.value = widget.focusNode.hasFocus;
    //wait until keyboard is open
    waitForKeyboardToOpen();
  }

  Future<Null> waitForKeyboardToOpenAndEnsureVisible() async {
    // Wait for the keyboard to come into view (if it isn't in view already)
    if(MediaQuery.of(context).viewInsets == EdgeInsets.zero) await waitForKeyboardToOpen();
    // ensure our focusNode is visible
    ensureVisible(context, widget.focusNode, duration: widget.duration, curve: widget.curve);
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
    return widget.child;
  }
}