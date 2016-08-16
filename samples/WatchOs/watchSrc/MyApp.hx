import InterfaceController;

class MyApp extends nme.watchos.App
{
   public function new()
   {
      super();
      trace("MyApp");
   }

   override public function onAwake()
   {
      trace(InterfaceController.instance);
      InterfaceController.instance.label0.setText("My Text!");

      //var bytes = haxe.io.Bytes.alloc(100);
      //var uiimage = nme.uikit.UIImage.imageWithData( bytes );
   }
}
