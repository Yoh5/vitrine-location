"""LOCAL SEULEMENT : jeton de connexion signé avec le secret de l'API locale (api_locale.sh).
Usage : python db/jeton_local.py gerant|demo  -> affiche le JSON de session à mettre dans le navigateur."""
import base64, hashlib, hmac, json, sys, time
SECRET = b"secret-local-de-developpement-32-caracteres-au-moins"
IDS = {"gerant": "00000000-0000-0000-0000-00000000000a", "demo": "00000000-0000-0000-0000-00000000000d"}
b64 = lambda b: base64.urlsafe_b64encode(b).rstrip(b"=").decode()
qui = sys.argv[1] if len(sys.argv) > 1 else "gerant"
exp = int(time.time()) + 8 * 3600
corps = {"sub": IDS[qui], "role": "authenticated", "exp": exp, "email": f"{qui}@exemple.test"}
t = b64(json.dumps({"alg": "HS256", "typ": "JWT"}).encode()) + "." + b64(json.dumps(corps).encode())
t += "." + b64(hmac.new(SECRET, t.encode(), hashlib.sha256).digest())
print(json.dumps({"access_token": t, "refresh_token": "local", "expires_at": exp, "email": corps["email"]}))
