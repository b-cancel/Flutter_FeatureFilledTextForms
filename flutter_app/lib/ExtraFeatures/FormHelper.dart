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
///     * "focusField"  needs it so refocusing works properly
///   - Animated Builders only rebuild if the value changes, if it was set to the exact same value it had before it is not considered a change
///     * this simplifies the code a bit
///   - the context parameter from "ensureVisible" must be have a "SingleChildScrollView" above it
///     * this is because that means "RenderAbstractViewport.of(object)" will have [RenderAbstractViewport] as an ancestor
///     * which means that ensureVisible will work

///-------------------------Enums-------------------------

enum FocusType {focusAndOpenKeyboard, focusAndCloseKeyboard, focusAndLeaveKeyboard}
enum ValidationScheme {validateAllThenRefocus, validateUntilRefocus}
enum ValidationType {check, checkAndShow}
enum SearchDirection {topToBottom, bottomToTop}
enum ReloadOn {fieldFocusChangeOrFieldEmptinessChange, fieldFocusChange, fieldEmptinessChange, never}
enum AppearOn {fieldFocusedAndFieldNotEmpty, fieldFocusedOrFieldNotEmpty, fieldFocused, fieldNotEmpty, always}
enum TextToShow {firstError, allErrors}
enum TextOrder {littleToBig, BigToLittle}

///-------------------------Functions-------------------------

///NOTE: this is only how most people would want to submit their field, BUT you might want different refocus settings per submission
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

focusField(BuildContext context, FocusNode focusNode, {FocusType focusType: FocusType.focusAndOpenKeyboard}) async {
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

bool doWeAppear(FormData formData, FocusNode focusNode, {AppearOn appearOn: AppearOn.fieldFocusedAndFieldNotEmpty}){
  if(appearOn == AppearOn.always){
    return true;
  }
  else{
    bool fieldFocused = focusNode.hasFocus;
    bool fieldNotEmpty = formData.focusNodeToTextInField[focusNode].value;
    if(appearOn == AppearOn.fieldFocusedAndFieldNotEmpty)
      return fieldFocused && fieldNotEmpty;
    else if(appearOn == AppearOn.fieldFocusedOrFieldNotEmpty)
      return fieldFocused || fieldNotEmpty;
    else if(appearOn == AppearOn.fieldFocused)
      return fieldFocused;
    else
      return fieldNotEmpty;
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

String generateErrorString(List<String> errors, TextOrder textOrder, TextToShow textToShow){
  if(errors.length == 0){
    return null;
  }
  else{
    //reverse the order of the errors if desired
    if(textOrder == TextOrder.littleToBig){
      errors = errors.reversed.toList();
    }
    //return the desired data
    if(textToShow == TextToShow.firstError){
      return errors[0];
    }
    else{
      String compiledResult;
      for(int i=0; i<errors.length; i++){
        if(i==0){
          compiledResult = errors[i];
        }
        else{
          compiledResult += "\n" + errors[i];
        }
      }
      return compiledResult;
    }
  }
}

///-------------------------Structure Classes-------------------------

class FormData{
  final GlobalKey<FormState> formKey;
  final BuildContext context;
  final Function submitForm;
  final List<FocusNode> focusNodes;
  final Map<FocusNode, ValueNotifier<String>> focusNodeToHelper;
  final Map<FocusNode, ValueNotifier<String>> focusNodeToError;
  final Map<FocusNode, Function> focusNodeToHelperRetrievers;
  final Map<FocusNode, Function> focusNodeToErrorRetrievers;
  final Map<FocusNode, TextEditingController> focusNodeToController;
  final Map<FocusNode, ValueNotifier<String>> focusNodeToValue;
  final Map<FocusNode, ValueNotifier<bool>> focusNodeToTextInField;
  final Map<FocusNode, Function> focusNodeToErrorDisplayers;

  FormData({
    this.formKey,
    this.context,
    this.submitForm,
    this.focusNodes,
    this.focusNodeToHelper,
    this.focusNodeToError,
    this.focusNodeToHelperRetrievers,
    this.focusNodeToErrorRetrievers,
    this.focusNodeToController,
    this.focusNodeToValue,
    this.focusNodeToTextInField,
    this.focusNodeToErrorDisplayers,
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
  final bool saveAndValidateFieldOnLoseFocus;
  final bool unFocusAllWhenTappingOutside;
  final bool keepTrackOfWhenFieldsBecomeEmpty;
  final bool reloadOnFieldEmptinessChange;
  final bool reloadOnFieldFocusChange;
  final bool reloadOnFieldContentChange;
  final bool autoSaveFieldValue;

  FormSettings({
    this.keyboardWait: const Duration(milliseconds: 50), //.05 seconds = 50 milliseconds
    this.scrollDuration: const Duration(milliseconds: 100),
    this.scrollCurve: Curves.ease,
    this.ensureVisibleOnFieldFocus: true,
    this.ensureVisibleOnReOpenKeyboard: true,
    this.ensureVisibleOnKeyboardType: true,
    this.ensureVisibleOnErrorAppear: true,
    this.saveAndValidateFieldOnLoseFocus: true,
    this.unFocusAllWhenTappingOutside: true,
    this.keepTrackOfWhenFieldsBecomeEmpty: true,
    this.reloadOnFieldEmptinessChange: true,
    this.reloadOnFieldFocusChange: true,
    this.reloadOnFieldContentChange: true,
    this.autoSaveFieldValue: true,
  });
}

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

///-------------------------Widgets-------------------------

///-------------------------Form Helper

class FormHelper extends StatefulWidget {
  final FormData formData;
  final FormSettings formSettings;
  final Widget child;
  final FocusNode focusNodeForInitialFocus;
  final FocusType focusTypeForInitialFocus;

  FormHelper({
    this.formData,
    this.formSettings,
    this.child,
    this.focusNodeForInitialFocus,
    this.focusTypeForInitialFocus: FocusType.focusAndLeaveKeyboard,
  });

  @override
  _FormHelperState createState() => _FormHelperState();
}

class _FormHelperState extends State<FormHelper> {
  //required so we can dispose when its time
  FocusNode emptyFocusNode;
  List<Function> saveAndValidateWhenLoseFocus;
  List<Function> controllerListenerFunctions;

  @override
  void initState() {
    //init parent before child
    super.initState();
    //save and validate field when it losses focus setup
    if(widget.formSettings.saveAndValidateFieldOnLoseFocus){
      saveAndValidateWhenLoseFocus = new List<Function>();
      for (int i = 0; i < widget.formData.focusNodes.length; i++) {
        FocusNode focusNode = widget.formData.focusNodes[i];
        saveAndValidateWhenLoseFocus.add(() {
          if (focusNode.hasFocus == false) {
            widget.formData.formKey.currentState.save();
            validateField(widget.formData, focusNode);
          }
        });
        widget.formData.focusNodes[i].addListener(saveAndValidateWhenLoseFocus[i]);
      }
    }
    //focusNode controller check if text exists in field setup
    if(widget.formData.focusNodeToController != null && (widget.formSettings.keepTrackOfWhenFieldsBecomeEmpty || widget.formSettings.autoSaveFieldValue)){
      controllerListenerFunctions = new List<Function>();
      for(int i=0; i<widget.formData.focusNodes.length; i++){
        FocusNode focusNode = widget.formData.focusNodes[i];
        controllerListenerFunctions.add((){
          if(widget.formSettings.autoSaveFieldValue){
            String prevValue = widget.formData.focusNodeToValue[focusNode].value;
            String currValue = widget.formData.focusNodeToController[focusNode].text;
            if(prevValue != currValue&& widget.formData.focusNodeToError[focusNode].value != null){
              widget.formData.focusNodeToError[focusNode].value = null; //this is done so that our helper text can become visible
            }
            widget.formData.focusNodeToValue[focusNode].value = widget.formData.focusNodeToController[focusNode].text;
            widget.formData.focusNodeToHelper[focusNode].value = widget.formData.focusNodeToHelperRetrievers[focusNode]();
          }
          if(widget.formSettings.keepTrackOfWhenFieldsBecomeEmpty && widget.formData.focusNodeToTextInField != null){
            if((widget.formData.focusNodeToController[focusNode].text.length ?? 0) > 0) widget.formData.focusNodeToTextInField[focusNode].value = true;
            else widget.formData.focusNodeToTextInField[focusNode].value = false;
          }
        });
        widget.formData.focusNodeToController[focusNode].addListener(controllerListenerFunctions[i]);
      }
    }
    //create the empty focus node if we are going to be using it
    if(widget.formSettings.unFocusAllWhenTappingOutside) emptyFocusNode = new FocusNode();
    //autoFocus the first node
    if (widget.focusNodeForInitialFocus != null) initFocus();
  }

  //the standard "TextFormField" "autoFocus" property doesn't automatically scroll. So we use this instead.
  initFocus() async {
    await Future.delayed(Duration.zero);
    focusField(widget.formData.context, widget.focusNodeForInitialFocus, focusType: widget.focusTypeForInitialFocus);
  }

  @override
  void dispose() {
    //save and validate field when it losses focus dispose
    if(widget.formSettings.saveAndValidateFieldOnLoseFocus){
      for(int i =0; i<widget.formData.focusNodes.length; i++){
        widget.formData.focusNodes[i].removeListener(saveAndValidateWhenLoseFocus[i]);
      }
    }
    //focusNode controller check if text exists in field dispose
    if(widget.formData.focusNodeToTextInField != null && widget.formData.focusNodeToController != null){
      for(int i=0; i<widget.formData.focusNodes.length; i++){
        widget.formData.focusNodeToController[widget.formData.focusNodes[i]].removeListener(controllerListenerFunctions[i]);
      }
    }
    //dispose of all focus nodes
    for(var focusNode in widget.formData.focusNodes){
      focusNode.dispose();
    }
    if(widget.formSettings.unFocusAllWhenTappingOutside) emptyFocusNode.dispose();
    //dispose parent after child
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

///-------------------------Text Form Field Helper

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

class _TextFormFieldHelperState extends State<TextFormFieldHelper> with WidgetsBindingObserver {

  @override
  void initState(){
    //init parent before child
    super.initState();
    if(widget.formSettings.ensureVisibleOnReOpenKeyboard) WidgetsBinding.instance.addObserver(this);
    if(widget.formSettings.ensureVisibleOnFieldFocus) widget.focusNode.addListener(waitForKeyboardToOpenAndEnsureVisible);
    if(widget.formSettings.ensureVisibleOnKeyboardType && widget.formData.focusNodeToController[widget.focusNode] != null){
      widget.formData.focusNodeToController[widget.focusNode].addListener(waitForKeyboardToOpenAndEnsureVisible);
    }
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

    //For Optimal Performance we want to the animated builders that update the least amount of times closer to the outside,
    // and those that update the most closer to the inside
    //LEAST TO MOST UPDATES
    //  1. focusNode,
    //  2. (focusNodeToTextInField[widget.focusNode] OR focusNodeToError[widget.focusNode]),
    //  3. focusNodeToController[widget.focusNode]

    //Developer Note: We could construct the widget and save ourselves some lines of code but it makes everything harder to understand

    //Note: we automatically assume that you want to rebuild your widget when an error appears because not doing so never makes sense
    // because it doesn't make sense to have errors and not let the user know they exist
    // if you don't want the field to be able to register errors then you can simply make the validator for that field always return true

    bool onFocusChange = widget.formSettings.reloadOnFieldFocusChange;
    bool onEmptinessChange = widget.formSettings.reloadOnFieldEmptinessChange;
    //onErrorDetected
    bool onContentChange = widget.formSettings.reloadOnFieldContentChange;

    if(onFocusChange && onEmptinessChange && onContentChange){ //---4 Animated Builders
      return new AnimatedBuilder(
        animation: widget.focusNode,
        builder: (context, child) {
          return new AnimatedBuilder(
            animation: widget.formData.focusNodeToTextInField[widget.focusNode],
            builder: (context, child) {
              return new AnimatedBuilder(
                animation: widget.formData.focusNodeToError[widget.focusNode],
                builder: (context, child){
                  if(widget.formSettings.ensureVisibleOnErrorAppear){
                    ensureVisible(context, widget.focusNode, duration: widget.formSettings.scrollDuration, curve: widget.formSettings.scrollCurve);
                  }
                  return new AnimatedBuilder(
                    animation: widget.formData.focusNodeToController[widget.focusNode],
                    builder: widget.builder,
                  );
                },
              );
            },
          );
        },
      );
    }
    else if(onFocusChange == false && onEmptinessChange == true && onContentChange == true ){ //---3 Animated Builders
      return new AnimatedBuilder(
        animation: widget.formData.focusNodeToTextInField[widget.focusNode],
        builder: (context, child) {
          return new AnimatedBuilder(
            animation: widget.formData.focusNodeToError[widget.focusNode],
            builder: (context, child){
              if(widget.formSettings.ensureVisibleOnErrorAppear){
                ensureVisible(context, widget.focusNode, duration: widget.formSettings.scrollDuration, curve: widget.formSettings.scrollCurve);
              }
              return new AnimatedBuilder(
                animation: widget.formData.focusNodeToController[widget.focusNode],
                builder: widget.builder,
              );
            },
          );
        },
      );
    }
    else if(onFocusChange == true && onEmptinessChange == false && onContentChange == true ){ //---3 Animated Builders
      return new AnimatedBuilder(
        animation: widget.focusNode,
        builder: (context, child) {
          return new AnimatedBuilder(
            animation: widget.formData.focusNodeToError[widget.focusNode],
            builder: (context, child){
              if(widget.formSettings.ensureVisibleOnErrorAppear){
                ensureVisible(context, widget.focusNode, duration: widget.formSettings.scrollDuration, curve: widget.formSettings.scrollCurve);
              }
              return new AnimatedBuilder(
                animation: widget.formData.focusNodeToController[widget.focusNode],
                builder: widget.builder,
              );
            },
          );
        },
      );
    }
    else if(onFocusChange == false && onEmptinessChange == false && onContentChange == true ){ //---2 Animated Builders
      return new AnimatedBuilder(
        animation: widget.formData.focusNodeToError[widget.focusNode],
        builder: (context, child){
          if(widget.formSettings.ensureVisibleOnErrorAppear){
            ensureVisible(context, widget.focusNode, duration: widget.formSettings.scrollDuration, curve: widget.formSettings.scrollCurve);
          }
          return new AnimatedBuilder(
            animation: widget.formData.focusNodeToController[widget.focusNode],
            builder: widget.builder,
          );
        },
      );
    }
    else if(onFocusChange == true && onEmptinessChange == true && onContentChange == false ){ //---3 Animated Builders
      return new AnimatedBuilder(
        animation: widget.focusNode,
        builder: (context, child) {
          return new AnimatedBuilder(
            animation: widget.formData.focusNodeToError[widget.focusNode], //INCORRECT order so that we can call ensure visible
            builder: (context, child){
              if(widget.formSettings.ensureVisibleOnErrorAppear){
                ensureVisible(context, widget.focusNode, duration: widget.formSettings.scrollDuration, curve: widget.formSettings.scrollCurve);
              }
              return new AnimatedBuilder(
                animation: widget.formData.focusNodeToTextInField[widget.focusNode], //INCORRECT order so that we can call ensure visible
                builder: widget.builder,
              );
            },
          );
        },
      );
    }
    else if(onFocusChange == false && onEmptinessChange == true && onContentChange == false ){ //---2 Animated Builders
      return new AnimatedBuilder(
        animation: widget.formData.focusNodeToError[widget.focusNode], //INCORRECT order so that we can call ensure visible
        builder: (context, child){
          if(widget.formSettings.ensureVisibleOnErrorAppear){
            ensureVisible(context, widget.focusNode, duration: widget.formSettings.scrollDuration, curve: widget.formSettings.scrollCurve);
          }
          return new AnimatedBuilder(
            animation: widget.formData.focusNodeToTextInField[widget.focusNode], //INCORRECT order so that we can call ensure visible
            builder: widget.builder,
          );
        },
      );
    }
    else if(onFocusChange == true && onEmptinessChange == false && onContentChange == false ){ //---2 Animated Builders
      return new AnimatedBuilder(
        animation: widget.formData.focusNodeToError[widget.focusNode], //INCORRECT order so that we can call ensure visible
        builder: (context, child){
          if(widget.formSettings.ensureVisibleOnErrorAppear){
            ensureVisible(context, widget.focusNode, duration: widget.formSettings.scrollDuration, curve: widget.formSettings.scrollCurve);
          }
          return new AnimatedBuilder(
            animation: widget.focusNode, //INCORRECT order so that we can call ensure visible
            builder: widget.builder,
          );
        },
      );
    }
    else{
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
                ensureVisible(context, widget.focusNode, duration: widget.formSettings.scrollDuration, curve: widget.formSettings.scrollCurve); //we already know we want this
                return new AnimatedBuilder(
                  animation: widget.formData.focusNodeToError[widget.focusNode],
                  builder: widget.builder,
                );
              },
          );
        }
      }
      else{
        return new AnimatedBuilder(
          animation: widget.formData.focusNodeToError[widget.focusNode],
          builder: widget.builder,
        );
      }
    }
  }

  @override
  void dispose(){
    if(widget.formSettings.ensureVisibleOnReOpenKeyboard) WidgetsBinding.instance.removeObserver(this);
    if(widget.formSettings.ensureVisibleOnFieldFocus) widget.focusNode.removeListener(waitForKeyboardToOpenAndEnsureVisible);
    if(widget.formSettings.ensureVisibleOnKeyboardType && widget.formData.focusNodeToController[widget.focusNode] != null) {
      widget.formData.focusNodeToController[widget.focusNode].removeListener(waitForKeyboardToOpenAndEnsureVisible);
    }
    //dispose child after parent
    super.dispose();
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