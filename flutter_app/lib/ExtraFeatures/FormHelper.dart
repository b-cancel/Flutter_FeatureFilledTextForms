import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Notes:
///   - this widget also automatically disposes of the focus nodes that you create and pass
///   - some features require some specific parameters
///     * because there are so many features that you can currently switch on and off, I have not required any parameters for the sake of release and testing (by yall)
///     * so you must manually make sure you have all the parameters that you require for the features you desire to use
///     * I will try to specify which parameters are required under what conditions soon but if you would like to help me that would be great
///   - some functions are async (and/or/xor) wait Duration.zero so that things can be scheduled properly
///     * "initFocus" needs this so that after build from your form runs and everything in the FormHelper is setup, then you are able to do a scrolling focus on your desired node
///     * "ensureVisible" only needs to be async so that when its called INIT or ON ERROR DETECTED it waits for build to run or for the error to show and then it ensures visible
///   - Animated Builders only rebuild if the value changes, if it was set to the exact same value it had before it is not considered a change
///     * this simplifies the code a bit
///   - the context parameter from "ensureVisible" must be have a "SingleChildScrollView" above it
///     * this is because that means "RenderAbstractViewport.of(object)" will have [RenderAbstractViewport] as an ancestor
///     * which means that ensureVisible will work

///-------------------------Form Helper Widget-------------------------

enum FocusType {focusAndOpenKeyboard, focusAndCloseKeyboard, focusAndLeaveKeyboard}

class FormHelper extends StatefulWidget {
  final FormData formData;
  final FormSettings formSettings;
  final Widget child;
  final FocusNode focusNodeForInitialFocus;
  final FocusType focusTypeForInitialFocus;

  FormHelper({
    this.formData,
    this.child,
    this.focusNodeForInitialFocus,
    this.focusTypeForInitialFocus: FocusType.focusAndLeaveKeyboard,
  });

  @override
  _FormHelperState createState() => _FormHelperState();
}

class _FormHelperState extends State<FormHelper> {
  FocusNode emptyFocusNode;

  @override
  void initState() {
    //create the empty focus node if we are going to be using it
    if(widget.formSettings.unFocusAllWhenTappingOutside) emptyFocusNode = new FocusNode();
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
    if(widget.formSettings.unFocusAllWhenTappingOutside) emptyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: GestureDetector(
        onTap: () {
          if(widget.formSettings.unFocusAllWhenTappingOutside) FocusScope.of(context).requestFocus(emptyFocusNode);
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

clearField(FormData formData, FocusNode focusNode, {bool validateFieldIfNotFocused: true}){
  saveField(formData.focusNodeToValue[focusNode], "");
  formData.focusNodeToController[focusNode].clear();
  formData.focusNodeToValue[focusNode].value = "";
  //if we clear the field when we are not focused on it
  //it makes sense that we validate the field because the user filled it out at one point
  //and if it has some requirements we want to make those are visible before the user tries to submit the form
  if(validateFieldIfNotFocused && focusNode.hasFocus == false)
    validateField(formData, focusNode);
}

saveField(ValueNotifier<String> value, String newValue) => value.value = newValue;

focusField(BuildContext context, FocusNode focusNode, {FocusType focusType: FocusType.focusAndOpenKeyboard}) {
  FocusScope.of(context).requestFocus(focusNode);
  if(focusType != FocusType.focusAndLeaveKeyboard){
    if(focusType == FocusType.focusAndOpenKeyboard) SystemChannels.textInput.invokeMethod('TextInput.show');
    else SystemChannels.textInput.invokeMethod('TextInput.hide');
  }
}

String validateField(FormData formData, FocusNode focusNode){
  //null error is no error (but still must be displayed to make error go away)
  String errorRetrieved = formData.focusNodeToErrorRetrievers[focusNode]();
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
  if(fieldToFocus != null) {
    focusField(formData.context, fieldToFocus, focusType: refocusSettings.focusType);
  }
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

  final FormData formData;
  final FormSettings formSettings;

  final FocusNode focusNode;
  final TransitionBuilder builder;

  const TextFormFieldHelper({
    this.formData,
    this.formSettings,

    this.focusNode,
    this.builder,
  });

  @override
  _TextFormFieldHelperState createState() => new _TextFormFieldHelperState();
}

class _TextFormFieldHelperState extends State<TextFormFieldHelper> with WidgetsBindingObserver  {

  //required so we can dispose of the listeners when its time
  Function trueWhenTextInField;
  Function saveAndValidateWhenLoseFocus;

  @override
  void initState(){
    super.initState();
    if(widget.formSettings.saveAndValidateFieldOnFieldFocusLoseFocus){
      //generate addressable function
      saveAndValidateWhenLoseFocus = () {
        if (widget.focusNode.hasFocus == false) {
          widget.formData.formKey.currentState.save();
          validateField(widget.formData, widget.focusNode);
        }
      };
      //set function to run when change detected
      widget.focusNode.addListener(saveAndValidateWhenLoseFocus);
    }
    //listeners to ensure visible on field focus and or ensure visible on re open keyboard
    if(widget.formSettings.ensureVisibleOnReOpenKeyboard) WidgetsBinding.instance.addObserver(this);
    else{
      if(widget.formSettings.ensureVisibleOnFieldFocus) widget.focusNode.addListener(waitForKeyboardToOpenAndEnsureVisible);
    }
    //listeners to ensure the field is keyboard on keyboard type
    if(widget.formSettings.ensureVisibleOnKeyboardType && widget.formData.focusNodeToController[widget.focusNode] != null){
      widget.formData.focusNodeToController[widget.focusNode].addListener(waitForKeyboardToOpenAndEnsureVisible);
    }
    //listeners to tell the value notifier whether or not there is some text in the field
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
    widget.focusNode.dispose();
    if(widget.formSettings.saveAndValidateFieldOnFieldFocusLoseFocus) widget.focusNode.removeListener(saveAndValidateWhenLoseFocus);
    if(widget.formSettings.ensureVisibleOnReOpenKeyboard) WidgetsBinding.instance.removeObserver(this);
    else{
      if(widget.formSettings.ensureVisibleOnFieldFocus) widget.focusNode.removeListener(waitForKeyboardToOpenAndEnsureVisible);
    }
    if(widget.formSettings.ensureVisibleOnKeyboardType && widget.formData.focusNodeToController[widget.focusNode] != null) {
      widget.formData.focusNodeToController[widget.focusNode].removeListener(waitForKeyboardToOpenAndEnsureVisible);
    }
    if(widget.formData.focusNodeToTextInField[widget.focusNode] != null && widget.formData.focusNodeToController[widget.focusNode] != null){
      widget.formData.focusNodeToController[widget.focusNode].removeListener(trueWhenTextInField);
    }
    super.dispose();
  }

  @override
  void didChangeMetrics(){
    if(widget.formSettings.ensureVisibleOnReOpenKeyboard && widget.focusNode.hasFocus) waitForKeyboardToOpenAndEnsureVisible();
  }

  Future<Null> waitForKeyboardToOpenAndEnsureVisible() async {
    // Wait for the keyboard to come into view (if it isn't in view already)
    if(MediaQuery.of(context).viewInsets == EdgeInsets.zero) await waitForKeyboardToOpen();
    // ensure our focusNode is visible
    ensureVisible(context, widget.focusNode, duration: widget.formSettings.scrollDuration, curve: widget.formSettings.scrollCurve);
  }

  Future<Null> waitForKeyboardToOpen() async {
    if (mounted){
      EdgeInsets closedInsets = MediaQuery.of(context).viewInsets;
      //this works because MediaQuery.of(context).viewInsets only changes ONCE when the keyboard is FULLY open
      while (mounted && MediaQuery.of(context).viewInsets == closedInsets) {
        await new Future.delayed(widget.formSettings.keyboardWait);
      }
    }
    return;
  }

  @override
  Widget build(BuildContext context) {
    //Note: The Order of the Animated Builders is very specific
    //Ideally in the outside we would have the animated builders that reload the least, and in the inside we would have the animated builders that reload the most
    //this would be to increase performance as much as possible so we reload the least amount of widgets per reload
    //  - focusNode changes the least because it only occurs when we un focus or focus on a field
    //  - focusNodeToTextInField has the chance of changing multiple times while the text field is focused
    //    * but it only changes when the text field goes from having some to no text, or no text to some text
    //    * this event generally doesn't happen all that often because it implies the user wiped all the text from the field
    //  - focusNodeToError changes the most because the user might adjust their input multiple times until they meet the requirements and are no longer generating an error on submission of that field
    //However, in order for ensureVisibleOnErrorAppear to work ensureVisible needs to run when the animated builder tied to widget.formData.focusNodeToError[widget.focusNode] rebuilds
    // since we pass a builder into this function, in order for this to always be possible we need to nest the focusNodeToTextInField Animated Builder into the focusNodeToError Animated Builder
    // although this solution is indeed suboptimal

    //Developer Note: For some reason IF I construct the widget piece by piece depending on the conditionals it doesn't function as expected
    // which is why im returning the entire widget depending on the conditionals and therefor repeat a lot of code

    //Note: we automatically assume that you want to rebuild your widget when an error appears because not doing so never makes sense
    // because it doesn't make sense to have errors and not let the user know they exist
    // if you don't want the field to be able to register errors then you can simply make the validator for that field always return true

    switch(widget.formSettings.clearFieldBtnAppearOn){
      case ClearFieldBtnAppearOn.fieldFocusedAndFieldNotEmpty:
        return new AnimatedBuilder(
          animation: widget.focusNode,
          builder: (context, child) {
            return new AnimatedBuilder(
              animation: widget.formData.focusNodeToError[widget.focusNode],
              builder: (context, child) {
                if(widget.formSettings.ensureVisibleOnErrorAppear) ensureVisible(context, widget.focusNode);
                return new AnimatedBuilder(
                  animation: widget.formData.focusNodeToTextInField[widget.focusNode],
                  builder: widget.builder,
                );
              },
            );
          },
        );
        break;
      case ClearFieldBtnAppearOn.fieldNotEmpty:
        return new AnimatedBuilder(
          animation: widget.formData.focusNodeToError[widget.focusNode],
          builder: (context, child) {
            if(widget.formSettings.ensureVisibleOnErrorAppear) ensureVisible(context, widget.focusNode);
            return new AnimatedBuilder(
              animation: widget.formData.focusNodeToTextInField[widget.focusNode],
              builder: widget.builder,
            );
          },
        );
        break;
      case ClearFieldBtnAppearOn.fieldFocused:
        return new AnimatedBuilder(
          animation: widget.formData.focusNodeToError[widget.focusNode],
          builder: (context, child) {
            if(widget.formSettings.ensureVisibleOnErrorAppear) ensureVisible(context, widget.focusNode);
            return new AnimatedBuilder(
              animation: widget.focusNode,
              builder: widget.builder,
            );
          },
        );
        break;
      default:
        if(widget.formSettings.ensureVisibleOnErrorAppear){
          //Note: this is a bit of a waste because two animated builders are rebuilding triggered by the exact SAME animation
          // but it simplifies the code for the user by not making them call ensureVisible manually
          //  Alternatively they could could call "ensureVisible(context, theFocusNodeNameHere)" in the builder they pass to this widget instead and set "alternatively" below to true
          bool alternatively = false;
          if(alternatively){
            return new AnimatedBuilder(
              animation: widget.formData.focusNodeToError[widget.focusNode],
              builder: widget.builder,
            );
          }
          else{
            return new AnimatedBuilder(
                animation: widget.formData.focusNodeToError[widget.focusNode],
                builder: (context, child){
                  ensureVisible(context, widget.focusNode); //we already know we want this
                  return new AnimatedBuilder(
                    animation: widget.formData.focusNodeToError[widget.focusNode],
                    builder: widget.builder,
                  );
                }
            );
          }
        }
        else{
          return new AnimatedBuilder(
            animation: widget.formData.focusNodeToError[widget.focusNode],
            builder: widget.builder,
          );
        }
        break;
    }
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
  final GlobalKey<FormState> formKey;
  final BuildContext context;
  final Function submitForm;
  final List<FocusNode> focusNodes;
  final Map<FocusNode, ValueNotifier<String>> focusNodeToError;
  final Map<FocusNode, Function> focusNodeToErrorRetrievers;
  final Map<FocusNode, TextEditingController> focusNodeToController;
  final Map<FocusNode, ValueNotifier<String>> focusNodeToValue;
  final Map<FocusNode, ValueNotifier<bool>> focusNodeToTextInField;

  FormData({
    this.formKey,
    this.context,
    this.submitForm,
    this.focusNodes,
    this.focusNodeToError,
    this.focusNodeToErrorRetrievers,
    this.focusNodeToController,
    this.focusNodeToValue,
    this.focusNodeToTextInField,
  });
}

class FormSettings{

  final Duration keyboardWait;
  final Duration scrollDuration;
  final Curve scrollCurve;
  final bool ensureVisibleOnFieldFocus;
  final bool ensureVisibleOnReOpenKeyboard;
  final bool ensureVisibleOnKeyboardType;
  final bool ensureVisibleOnErrorAppear;
  final ClearFieldBtnAppearOn clearFieldBtnAppearOn;
  final bool saveAndValidateFieldOnFieldFocusLoseFocus;
  final bool unFocusAllWhenTappingOutside;

  FormSettings({
    this.keyboardWait: const Duration(milliseconds: 50), //.05 seconds = 50 milliseconds
    this.scrollDuration: const Duration(milliseconds: 100),
    this.scrollCurve: Curves.ease,
    this.ensureVisibleOnFieldFocus: true,
    this.ensureVisibleOnReOpenKeyboard: true,
    this.ensureVisibleOnKeyboardType: true,
    this.ensureVisibleOnErrorAppear: true,
    this.clearFieldBtnAppearOn: ClearFieldBtnAppearOn.fieldFocusedAndFieldNotEmpty,
    this.saveAndValidateFieldOnFieldFocusLoseFocus: true,
    this.unFocusAllWhenTappingOutside: true,
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

///-------------------------Extra Helper Widgets-------------------------

Widget passwordShowHideButton(bool show, {Color iconColor,}){
  return new Padding(
    padding: const EdgeInsets.only(left: 8.0),
    child: (show)
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

enum ClearFieldBtnAppearOn {fieldFocused, fieldNotEmpty, fieldFocusedAndFieldNotEmpty, never}

Widget clearFieldButton(FormData formData, FocusNode focusNode, {ClearFieldBtnAppearOn clearFieldButtonAppearOn: ClearFieldBtnAppearOn.fieldFocusedAndFieldNotEmpty}){
  bool fieldFocused = focusNode.hasFocus;
  bool fieldNotEmpty = formData.focusNodeToTextInField[focusNode].value;
  Widget show = new GestureDetector(
    onTap: () =>  clearField(formData, focusNode),
    child: new Icon(Icons.close),
  );
  Widget hide = new Text("");

  switch(clearFieldButtonAppearOn){
    case ClearFieldBtnAppearOn.fieldFocusedAndFieldNotEmpty:
      if(fieldFocused && fieldNotEmpty ) return show;
      else return hide;
      break;
    case ClearFieldBtnAppearOn.fieldFocused:
      if(fieldFocused) return show;
      else return hide;
      break;
    case ClearFieldBtnAppearOn.fieldNotEmpty:
      if(fieldNotEmpty) return show;
      else return hide;
      break;
    default:
      return hide;
      break;
  }
}