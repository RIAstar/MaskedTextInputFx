package net.riastar.components {

import flash.events.Event;

import flashx.textLayout.elements.ParagraphElement;
import flashx.textLayout.elements.SpanElement;
import flashx.textLayout.elements.TextFlow;
import flashx.textLayout.operations.DeleteTextOperation;
import flashx.textLayout.operations.FlowOperation;
import flashx.textLayout.operations.InsertTextOperation;

import mx.events.FlexEvent;

import spark.components.RichEditableText;
import spark.components.TextInput;
import spark.events.TextOperationEvent;


/**
 * The color of the replaceable characters in the <code>textMask</code>
 * @default 0x000000
 */
[Style(name="maskColor", inherit="no", type="uint")]

/**
 * The alpha transparency of the replaceable characters in the <code>textMask</code>
 * @default .3
 */
[Style(name="maskAlpha", inherit="no", type="Number")]


/**
 * MaskedTextInput is a TextInput that uses a <code>textMask</code> to force a certain formatting on the user's input.
 * It can be used for a wide range of formats. Some example formats:
 *
 * <ul>
 * <li><b>date:</b>dd/mm/yyyy</li>
 * <li><b>belgian bank number:</b>***-*******-**</li>
 * <li><b>BIC:</b>bbbbcclliii</li>
 * <li><b>credit card:</b>####-####-####-####</li>
 * <li><b>pincode:</b>****</li>
 * <li><b>belgian national register number:</b>##.##.##-###.##</li>
 * </ul>
 *
 * Some of the characters in the <code>textMask</code> are considered <code>delimiters</code>.
 * These characters don't get replaced or deleted when the user changes the input.
 * Other characters of the <code>textMask</code> do get replaced by the user's input.<br/>
 * The delimiter characters are displayed with the same styling as the main <code>text</code> style,
 * whereas the replaceable characters have a different style:
 * use the <code>maskColor</code> and <code>maskAlpha</code> styles to adjust their look and feel.<br/><br/>
 *
 * The default delimiters are <code>/ \ | : - . ( ) [ ] { } &lt;</code> and <code>&gt;</code>
 * but this can be overridden through the <code>deleimters</code> property.
 *
 * @langversion ActionScript 3.0, Flex 4.6
 * @playerversion Flash 11.1
 * @author Maxime Cowez
 * @tiptext MaskedTextInput A TextInput with a mask that forces formatting
 */
public class MaskedTextInput extends TextInput {

    /* ------------------ */
    /* --- properties --- */
    /* ------------------ */

    /** Characters that have to be escaped when building the <code>delimiterRegex</code> property */
    private const regexEscape:String = "/\\|.*+?$^'#()[]{}bBdDsSwW";

    /** The characters from the <code>textMask</code> property that aren't delimiters and can be replaced */
    private var replaceableChars:String;
    /** The regular expression used to find the replaceable characters */
    private var delimiterRegex:RegExp;

    private var _delimiters:String = "/\\|:-.()[]{}<>";
    /**
     * Characters in the <code>textMask</code> that won't be replaced or deleted when the user edits the input field.
     * These characters will be displayed in the same color and alpha as the user's input
     * (as opposed to the characters from the <code>textMask</code> that aren't delimiters).
     * Also the cursor will jump over these characters while typing.
     *
     * @default /\\|:-.()[]{}<>
     */
    public function get delimiters():String {
        return _delimiters;
    }
    public function set delimiters(value:String):void {
        _delimiters = value;
        delimiterRegex = createDelimiterRegex(value);
        replaceableChars = _textMask ? _textMask.replace(delimiterRegex, '') : "";
        if (richText) richText.textFlow = createTextFlow(_textMask);
    }

    private var _textMask:String;
    /**
     * A set of characters the will be replaced as the user types.
     * They will be presented differently than the real input text:
     * their presentation can be configured through the <code>maskColor</code> and <code>maskAlpha</code> styles.
     * Some of the characters can be delimiters and won't be replaced (see <code>delimiters</code> property).
     * This property is <b>required</b>.
     */
    public function get textMask():String {
        return _textMask;
    }
    public function set textMask(value:String):void {
        _textMask = value;
        replaceableChars = value ? value.replace(delimiterRegex, '') : "";
        if (richText) richText.textFlow = createTextFlow(value);
    }

    private var _isComplete:Boolean;
    [Bindable("isCompleteChanged")]
    public function get isComplete():Boolean {
        return _isComplete;
    }
    public function set isComplete(value:Boolean):void {
        _isComplete = value;
        dispatchEvent(new Event("isCompleteChanged"));
    }

    [Bindable("change")]
    [Bindable("textChanged")]
    /** @private */
    override public function set text(value:String):void {
        super.text = value;
        updateIsComplete();
        if (richText) richText.textFlow = createTextFlow(value);
    }

    /** A more specifically typed reference to the <code>textDisplay</code>, just for convenience */
    private var richText:RichEditableText;
    /** Whether to prevent events from being dispatched; used for silently setting <code>text</code> */
    private var preventEvents:Boolean;


    /* -------------------- */
    /* --- construction --- */
    /* -------------------- */

    public function MaskedTextInput() {
        //set default value to force derived calculations
        delimiters = _delimiters;
    }

    override protected function partAdded(partName:String, instance:Object):void {
        super.partAdded(partName, instance);

        switch (instance) {
            case textDisplay:
                richText = RichEditableText(textDisplay);
                richText.textFlow = createTextFlow(text);
                textDisplay.addEventListener(TextOperationEvent.CHANGING, handleTextOperation);
                break;
        }
    }


    /* ---------------------- */
    /* --- event handlers --- */
    /* ---------------------- */

    private function handleTextOperation(event:TextOperationEvent):void {
        event.preventDefault();

        var operation:FlowOperation = event.operation;
        if (operation is InsertTextOperation)
            insertChar(operation as InsertTextOperation);
        if (operation is DeleteTextOperation)
            deleteSelection(operation as DeleteTextOperation);
    }


    /* ----------------- */
    /* --- behaviour --- */
    /* ----------------- */

    /**
     * Takes a list of delimiters (actually just characters as a String)
     * and creates a regular expression we can use to filter them from the <code>textMask</code>.
     * This step is necessary because a lot of these delimiter characters
     * have to be escaped in a regular expression.
     *
     * @param delimiters The delimiter characters as a String
     */
    protected function createDelimiterRegex(delimiters:String):RegExp {
        var regex:String = "";
        var numChars:int = delimiters ? delimiters.length : 0;

        for (var i:int = 0; i < numChars; i++) {
            var char:String = delimiters.charAt(i);
            regex += "|" + (regexEscape.indexOf(char) == -1 ? "" : "\\") + char;
        }

        return new RegExp(regex.substr(1), "gm");
    }

    /**
     * Silently sets the <code>text</code> property, i.e. events will not be dispatched
     *
     * @param value The new text
     */
    protected function setText(value:String):void {
        if (text == value) return;

        preventEvents = true;
        text = value;
        preventEvents = false;
    }

    /**
     * Inserts a character the user types at the right position.
     * If the cursor is at a replaceable character, it'll be replaced.
     * If it's at a delimiter, the next replaceable character will be replaced.
     * If it's at the end of the <code>textMask</code> nothing happens.
     * The cursor is then set before the next replaceable character,
     * jumping over any delimiters.
     *
     * @param operation The <code>InsertTextOperation</code> that carries the necessary info to insert the text
     */
    protected function insertChar(operation:InsertTextOperation):void {
        var index:int = operation.absoluteStart;
        if (index >= text.length) return;

        //insert the new character at the next valid index
        index = getNextCharPosition(index);
        setText(text.substr(0, index) + operation.text + text.substr(index + 1));

        //set the cursor at the next valid index after the inserted character
        index = getNextCharPosition(index + 1);
        richText.selectRange(index, index);
    }

    /**
     * Replaces the text selection with the text from the <code>textMask</code>
     * and sets the cursor at the beginning of that selection so the user can start typing again.
     *
     * @param operation The <code>DeleteTextOperation</code> that carries the necessary info to delete the text
     */
    protected function deleteSelection(operation:DeleteTextOperation):void {
        var start:int = operation.absoluteStart;
        var end:int = operation.absoluteEnd;

        //replace selected text with mask text and set cursor at the start of the selection
        setText(text.substr(0, start) + textMask.substring(start, end) + text.substr(end));
        richText.selectRange(start, start);
    }

    /**
     * Finds the index of the first replaceable character in the <code>textMask</code> after a given position.
     * Starts searching from index 0 by default.
     *
     * @param start The index from which to start searching for replaceable characters; default 0
     * @return The index of the first replaceable character
     */
    protected function getNextCharPosition(start:int = 0):int {
        if (start >= text.length) return start;

        while (delimiters.indexOf(text.charAt(start)) != -1) {
            start++;
        }

        return start;
    }

    /**
     * Takes a text, compares it to the <code>textMask</code>
     * and creates a <code>TextFlow</code> object with input text and delimiters in the normal text style,
     * and replaceable <code>textMask</code> characters with a different style.
     * See <code>maskColor</code> and <code>maskAlpha</code> styles to configure the replaceable character style.
     *
     * @param text The text that will be converted
     * @return The <code>TextFlow</code> with different stylings
     */
    protected function createTextFlow(text:String):TextFlow {
        if (!text) text = _textMask;
        if (!text || !_textMask) return null;

        var textFlow:TextFlow = new TextFlow();
        var p:ParagraphElement = new ParagraphElement();
        var maskColor:uint = getStyle("maskColor");
        var maskAlpha:Number = getStyle("maskAlpha");
        if (isNaN(maskAlpha)) maskAlpha = .3;

        for (var i:int = 0; i < text.length; i++) {
            var span:SpanElement = new SpanElement();
            var char:String = text.charAt(i);
            span.text = char;

            if (replaceableChars.indexOf(char) != -1) {
                span.color = maskColor;
                span.textAlpha = maskAlpha;
            }

            p.addChild(span);
        }

        textFlow.mxmlChildren = [p];
        return textFlow;
    }

    protected function updateIsComplete():void {
        var numChars:int = text.length;
        if (!numChars) {
            isComplete = false;
            return;
        }

        for (var i:int = 0; i < numChars; i++) {
            if (replaceableChars.indexOf(text.charAt(i)) != -1) {
                isComplete = false;
                return;
            }
        }

        isComplete = true;
    }

    /**
     * Since the styling of the mask text is not done in <code>updateDiplayList()</code>,
     * we need to update the <code>textFlow</code> whenever the mask styles change.
     * @private
     */
    override public function styleChanged(styleProp:String):void {
        super.styleChanged(styleProp);
        if (richText) richText.textFlow = createTextFlow(text);
    }

    /** @private */
    override public function dispatchEvent(event:Event):Boolean {
        return preventEvents && event.type == FlexEvent.VALUE_COMMIT ? false : super.dispatchEvent(event);
    }

}
}
