"use strict";

import PointerEvent from "./pointer_event.ts";

export default class ClickOutsideEvent {
  static isDefaultAllowed = true;

  static buildOperationParam(event) {
    return PointerEvent.buildOperationParam(event);
  }

  static isEventIgnored(_event) {
    return false;
  }
}
