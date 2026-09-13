$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$out = "F:\Disassertation\PySAST\PySAST-repro\reports-v2\screenshots"
& $edge --headless --disable-gpu "--screenshot=$out\applio-gui.png" --window-size=1600,1000 --virtual-time-budget=12000 "http://127.0.0.1:6969/"
Start-Sleep -Seconds 3
Get-ChildItem $out
