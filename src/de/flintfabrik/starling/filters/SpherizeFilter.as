/**
 *	Copyright (c) 2013 Michael Trenkler
 *
 *	Permission is hereby granted, free of charge, to any person obtaining a copy
 *	of this software and associated documentation files (the "Software"), to deal
 *	in the Software without restriction, including without limitation the rights
 *	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *	copies of the Software, and to permit persons to whom the Software is
 *	furnished to do so, subject to the following conditions:
 *
 *	The above copyright notice and this permission notice shall be included in
 *	all copies or substantial portions of the Software.
 *
 *	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *	THE SOFTWARE.
 */

package de.flintfabrik.starling.filters
{
	import flash.display3D.Context3D;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Program3D;
	import starling.core.RenderSupport;
	import starling.display.DisplayObject;
	import starling.filters.FragmentFilter;
	import starling.textures.Texture;
    
    /** The SpherizeFilter class applies a simple lens effect knwon from 
	 *  screensavers and similar stuff.
	 *
	 *  @see starling.filters.FragmentFilter
	 *
	 *  @see http://www.flintfabrik.de
	 *  @author Michael Trenkler
     */
    public class SpherizeFilter extends FragmentFilter
    {
		private var mAmount:Number = 1;
		private var mCutout:Boolean = false;
		private var mObjectHeight:Number = 0;
		private var mObjectWidth:Number = 0;
		private var mRadius:Number = 0.5;
        private var mShaderProgram:Program3D;
        private var mShaderVars:Vector.<Number> = new <Number>[0, 0, 0, 0];
		private var mX:Number = 0.5;
		private var mY:Number = 0.5;
		
		
        /** Creates a new SpherizeFilter instance with the specified arguments. 
         *  @param amount: values from -1 to 1 resulting in a concave/convex sphere
		 *  @param radius: the radius of the sphere
         */
        public function SpherizeFilter(amount:Number = 1, radius:Number=0.5, resolution:Number=1)
        {
			this.amount = amount;
			this.radius = radius;
			super(1, resolution);
        }
		
		/** @private */
        protected override function activate(pass:int, context:Context3D, texture:Texture):void
        {
			var aspectRatio:Number = texture.height / texture.width;
			mShaderVars = new <Number> [
				mX * mObjectWidth/texture.width  /* center x (u) */,
				mY * mObjectHeight/texture.height/* center y (v) */,
				mRadius,
				aspectRatio,
				
				0.5 * Math.PI,
				(2/Math.PI) * -mAmount, //amount
				mCutout ? 0 : 1,
				0
			  ];
			
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, mShaderVars, 2);
            context.setProgram(mShaderProgram);
        }
		
        /** @private */
        protected override function createPrograms():void
        {
			if (mShaderProgram) mShaderProgram.dispose();
			
			var fragmentProgramCode:String =
				"mov ft0, v0					\n" +
				"sub ft1.xy, ft0.xy, fc0.xy		\n" +
				"mov ft1.zw, fc1.ww				\n" +
				
				// aspectRatio
				"mov ft2 ft1					\n" +
				"mul ft2.y, ft2.y, fc0.w		\n" +
				
				// distance to center
				"sub ft2.zw, ft2.zw, ft2.zw		\n" +
				"dp3 ft2, ft2, ft2				\n" + 
				"sqt ft2, ft2					\n" +
				
				// cutout 
				"sge ft3.xy, ft2.xy, fc0.zz		\n" +
				"mul ft3.xy, ft3.xy, fc1.zz		\n" +
				
				// inner
				"slt ft4.xy, ft2.xy, fc0.zz		\n" +
				
					"div ft5.xy, ft2.xy, fc0.zz		\n" + // normalize to percent
					"mul ft5.xy, ft5.xy, fc1.xx		\n" + // * PI/2
					"cos ft5.xy, ft5.xy				\n" + // spherize
					
					"mul ft5.xy, ft5.xy, fc1.yy		\n" + // * amount
					"mul ft5.xy, ft5.xy, ft1.xy		\n" + // * distortion
					"add ft5.xy, ft5.xy, ft1.xy		\n" + // undistored + distored combined
					
					"add ft5.xy, fc0.xy, ft5.xy		\n" + // + center
					
				"mul ft6.xy, ft0.xy, ft3.xy		\n" + // outer
				"mul ft7.xy, ft5.xy, ft4.xy		\n" + // inner
				"add ft7.xy, ft6.xy, ft7.xy		\n" + // inner + outer combined 
				
				"tex oc, ft7.xy, fs0<2d, clamp, linear, mipnone>	\n";
				
            mShaderProgram = assembleAgal(fragmentProgramCode);
        }
		
        /** @inheritDoc */
        public override function dispose():void
        {
            if (mShaderProgram) mShaderProgram.dispose();
            super.dispose();
        }
        
		public override function render(object:DisplayObject, support:RenderSupport, parentAlpha:Number):void
        {
			if (object) {
				mObjectWidth = object.width
				mObjectHeight = object.height;
			}
			super.render(object, support, parentAlpha);
		}
		
		/**
		 * Amount of applied effect. Can be a positive or negative number resulting in a CW/CCW spiral.
		 */
		public function get amount():Number 
		{
			return mAmount;
		}
		
		public function set amount(value:Number):void 
		{
			mAmount = Math.max( -1, Math.min(value, 1));
		}
		/**
		 * If set to true the image will get clipped beyond the effect border.
		 */
		public function get cutout():Boolean 
		{
			return mCutout;
		}
		
		public function set cutout(value:Boolean):void 
		{
			mCutout = value;
		}
		/**
		 * The radius of the effect.
		 */
		public function get radius():Number 
		{
			return mRadius;
		}
		
		public function set radius(value:Number):void 
		{
			mRadius = Math.max(0, value);
		}
		/**
		 * X-position of the center
		 */
		public function get x():Number 
		{
			return mX;
		}
		
		public function set x(value:Number):void 
		{
			mX = value;
		}
		/**
		 * Y-position of the center
		 */
		public function get y():Number 
		{
			return mY;
		}
		
		public function set y(value:Number):void 
		{
			mY = value;
		}
    }
}