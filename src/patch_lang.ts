#!/usr/bin/env node

import { readFileSync, writeFileSync } from "fs";

const LANGUAGE_FILENAME: string = `${process.env.HOME}/resources/app/public/lang/en.json`;
let data: any = JSON.parse(readFileSync(LANGUAGE_FILENAME, "utf8"));

data["SETUP.UpdateHint"] = data["SETUP.UpdateNoUpdateMode"] =
  "This instance of Foundry Virtual Tabletop is running in a " +
  "Docker container.  To update, please use your account admin panel to setup new instance.";

writeFileSync(LANGUAGE_FILENAME, JSON.stringify(data, null, "  "));
