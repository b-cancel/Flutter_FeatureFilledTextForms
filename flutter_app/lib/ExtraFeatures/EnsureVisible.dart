import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

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

class EnsureVisible extends StatefulWidget {

  final FocusNode focusNode;
  final Duration duration; //time it takes us to scroll ourselves into view
  final Curve curve; //the curve we use to scroll ourselves into view
  final Duration keyboardWait; //the time we wait to once again check if the keyboard is finally open
  final Widget child;

  const EnsureVisible({
    Key key,
    @required this.focusNode,
    this.duration: const Duration(milliseconds: 100),
    this.curve: Curves.ease,
    //what most humans consider instant is .1 seconds, so we want to check if the keyboard is finally open a little bit more often than that .05 seconds
    this.keyboardWait: const Duration(milliseconds: 50), //.05 seconds = 50 milliseconds
    @required this.child,
  }) : super(key: key);

  @override
  _EnsureVisibleWhenFocusedState createState() => new _EnsureVisibleWhenFocusedState();
}

class _EnsureVisibleWhenFocusedState extends State<EnsureVisible> with WidgetsBindingObserver  {

  @override
  void initState(){
    super.initState();
    widget.focusNode.addListener(_waitForKeyboardToOpenAndEnsureVisible);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose(){
    WidgetsBinding.instance.removeObserver(this);
    widget.focusNode.removeListener(_waitForKeyboardToOpenAndEnsureVisible);
    super.dispose();
  }

  @override
  void didChangeMetrics(){
    if(widget.focusNode.hasFocus) _waitForKeyboardToOpenAndEnsureVisible();
  }

  Future<Null> _waitForKeyboardToOpen() async {
    if (mounted){
      EdgeInsets closedInsets = MediaQuery.of(context).viewInsets;
      //this works because MediaQuery.of(context).viewInsets only changes ONCE when the keyboard is FULLY open
      while (mounted && MediaQuery.of(context).viewInsets == closedInsets) {
        await new Future.delayed(widget.keyboardWait);
      }
    }
    return;
  }

  Future<Null> _waitForKeyboardToOpenAndEnsureVisible() async {
    // Wait for the keyboard to come into view (if it isn't in view already)
    if(MediaQuery.of(context).viewInsets == EdgeInsets.zero) await _waitForKeyboardToOpen();
    // ensure our focusNode is visible
    ensureVisible(context, widget.focusNode, duration: widget.duration, curve: widget.curve);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

ensureVisible(BuildContext context, FocusNode focusNode, {Duration duration: const Duration(milliseconds: 100), Curve curve: Curves.ease}){
  // No need to go any further if the node has not the focus
  if (focusNode.hasFocus){
    // Find the object which has the focus
    final RenderObject object = context.findRenderObject();
    final RenderAbstractViewport viewport = RenderAbstractViewport.of(object);
    assert(viewport != null);

    // Get the Scrollable state (in order to retrieve its offset)
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

ensureErrorVisible( context, focusNode, {Duration duration: const Duration(milliseconds: 100), Curve curve: Curves.ease,}) async => ensureVisible(context, focusNode, duration: duration, curve: curve);

class KeyboardListener extends TextInputFormatter {

  final BuildContext context;
  final FocusNode focusNode;
  final Duration duration;
  final Curve curve;

  KeyboardListener(this.context, this.focusNode, {this.duration: const Duration(milliseconds: 100), this.curve: Curves.ease});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ){
    ensureVisible(context, focusNode, duration: duration, curve: curve);
    return newValue;
  }
}