"use strict";

import {assert, defineRuntimeGlobals, sinon} from "../support/helpers.mjs";

import MouseEvent from "hologram:runtime/events/mouse_event";
import PointerEvent from "hologram:runtime/events/pointer_event";
import Type from "hologram:runtime/type";

defineRuntimeGlobals();

describe("PointerEvent", () => {
  describe("buildOperationParam()", () => {
    it("known pointer type", () => {
      const event = {
        clientX: 10,
        clientY: 20,
        movementX: 5,
        movementY: 15,
        offsetX: 30,
        offsetY: 40,
        pageX: 1,
        pageY: 2,
        pointerType: "mouse",
        screenX: 100,
        screenY: 200,
      };

      const result = PointerEvent.buildOperationParam(event);

      const expected = Type.map([
        [Type.atom("client_x"), Type.float(10)],
        [Type.atom("client_y"), Type.float(20)],
        [Type.atom("movement_x"), Type.float(5)],
        [Type.atom("movement_y"), Type.float(15)],
        [Type.atom("offset_x"), Type.float(30)],
        [Type.atom("offset_y"), Type.float(40)],
        [Type.atom("page_x"), Type.float(1)],
        [Type.atom("page_y"), Type.float(2)],
        [Type.atom("pointer_type"), Type.atom("mouse")],
        [Type.atom("screen_x"), Type.float(100)],
        [Type.atom("screen_y"), Type.float(200)],
      ]);

      assert.deepStrictEqual(result, expected);
    });

    it("unknown pointer type", () => {
      const event = {
        clientX: 10,
        clientY: 20,
        movementX: 5,
        movementY: 15,
        offsetX: 30,
        offsetY: 40,
        pageX: 1,
        pageY: 2,
        pointerType: "",
        screenX: 100,
        screenY: 200,
      };

      const result = PointerEvent.buildOperationParam(event);

      const expected = Type.map([
        [Type.atom("client_x"), Type.float(10)],
        [Type.atom("client_y"), Type.float(20)],
        [Type.atom("movement_x"), Type.float(5)],
        [Type.atom("movement_y"), Type.float(15)],
        [Type.atom("offset_x"), Type.float(30)],
        [Type.atom("offset_y"), Type.float(40)],
        [Type.atom("page_x"), Type.float(1)],
        [Type.atom("page_y"), Type.float(2)],
        [Type.atom("pointer_type"), Type.nil()],
        [Type.atom("screen_x"), Type.float(100)],
        [Type.atom("screen_y"), Type.float(200)],
      ]);

      assert.deepStrictEqual(result, expected);
    });
  });

  it("isEventIgnored()", () => {
    const mouseEventIsEventIgnoredStub = sinon
      .stub(MouseEvent, "isEventIgnored")
      .callsFake(() => null);

    PointerEvent.isEventIgnored("dummy_event");

    sinon.assert.calledOnceWithExactly(
      mouseEventIsEventIgnoredStub,
      "dummy_event",
    );

    MouseEvent.isEventIgnored.restore();
  });
});
