import { userLite_of_json } from "./componentSchemas.annotated.mjs";
import * as J from "melange-json/melange_json.js";
const raw = JSON.stringify({ id:"u1", name:"Shiro", username:"shiro", host:"misskey.io",
  avatarUrl:"https://x/a.png", avatarBlurhash:"abc", avatarDecorations:[], emojis:{},
  onlineStatus:"online", isBot:true });
const u = userLite_of_json(J.of_string(raw));
console.log("id =", u.id, "| onlineStatus =", u.onlineStatus, "| isBot =", u.isBot,
            "| avatarDecorations Array?", Array.isArray(u.avatarDecorations),
            "| isCat (absent) =", JSON.stringify(u.isCat));
