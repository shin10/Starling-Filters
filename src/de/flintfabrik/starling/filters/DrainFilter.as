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
 * 
 *  This Code also includes makc3d's AGAL version of atan2 which was released
 *  under MIT License. For more information visit: http://wonderfl.net/c/mS2W
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
    
    
    /** The DrainFilter class applies an distortion effect, for something like 
	 *  a "plug hole", "black hole" or what ever.
	 *
	 *  @see starling.filters.FragmentFilter
	 *
	 *  @see http://www.flintfabrik.de
	 *  @author Michael Trenkler
     */
    public class DrainFilter extends FragmentFilter
    {
		
		private var mAmount:Number = 1;
        private var mClamp:Boolean = true;
		private var mObjectHeight:Number = 0;
		private var mObjectWidth:Number = 0;
		private var mRadius:Number = 0.5;
        private var mShaderProgram:Program3D;
        private var mShaderVars:Vector.<Number> = new <Number>[0,0,0,0, 0,0,0,0, 0,0,0,0];
		private var mX:Number = 0.5;
		private var mY:Number = 0.5;
		
        /** Creates a new DrainFilter instance.
         */
        public function DrainFilter(resolution:Number=1)
        {
			super(1, resolution);
        }
		
        /** @private */
        protected override function activate(pass:int, context:Context3D, texture:Texture):void
        {
			
			mShaderVars = new <Number> [
					mX * mObjectWidth/texture.width  /* center x (u) */,
					mY * mObjectHeight/texture.height/* center y (v) */,
					0,
					1,
					
					mRadius * (mObjectWidth/texture.width),
					Math.PI*.5,
					mAmount*.25,
					(texture.width / texture.height)
				];
			
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, mShaderVars);
            context.setProgram(mShaderProgram);
        }
        
        /** @private */
        protected override function createPrograms():void
        {
			if (mShaderProgram) mShaderProgram.dispose();
			
			var fragmentProgramCode:String =
			"sub ft0.xyzw, v0.xyzw, fc0.xyzz	\n" + // - center (center distance, orthogonal)
				"mul ft0.x, ft0.x, fc1.w		\n" + // aspect ratio
			
			// direct (diagonal) distance to center
			"sub ft0.zw, ft0.zw, ft0.zw			\n" +
			"dp3 ft1, ft0, ft0					\n" +
			"sqt ft1, ft1						\n" +
			
			// effect radius
			"div ft1.y, ft1.x, fc1.x			\n" + // / r1
			// distance to outer effect border
			"sub ft1.z, fc0.w, ft1.y			\n" + // 1 -
			
			//distortion
			"div ft4.xy, ft0.xy, ft1.yy			\n" + // border distance to center, orthogonal
			"mul ft4.xy, ft4.xy, ft1.zz			\n" + // * r1r2 amount
			"mul ft4.xy, ft4.xy, ft1.zz			\n" + // * r1r2 amount
			"mul ft4.xy, ft4.xy, fc1.zz			\n" + // * custom amount
			
			// clamping the effect
			"slt ft3.z, ft1.y, fc0.w			\n" + // < 1
			"mul ft4.xy, ft4.xy, ft3.zz		\n" +
			// combined texels
			"add ft5.xy, v0.xy, ft4.xy		\n" +
			"tex ft6, ft5.xy, fs0<2d, clamp, linear, mipnone>	\n" +
			
			// cropping texture left/top
			"sge ft3.xy, ft5.xy, fc0.zz			\n" +
			"mul ft3.x, ft3.x, ft3.y			\n" +
			"mul oc.xyzw, ft6.xyzw, ft3.xxxx	\n";
			
            mShaderProgram = assembleAgal(fragmentProgramCode);
        }
		 
        /** @inheritDoc */
        public override function dispose():void
        {
            if (mShaderProgram) mShaderProgram.dispose();
            super.dispose();
        }
		
		/** @private */
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
			value = Math.max(0, Math.min(value, 1));
			if (mAmount != value) {
				mAmount = value;
				if (isCached) cache();
			}
		}
		/**
		 * Whether the effect should be clamped or erased on texture borders.
		 */
		public function get clamp():Boolean 
		{
			return mClamp;
		}
		
		public function set clamp(value:Boolean):void 
		{
			if (mClamp != value) {
				mClamp = value;
				createPrograms();
				if (isCached) cache();
			}
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
			value = Math.max(0, Math.min(value, 255));
			if (mRadius != value) {
				mRadius = value;
				if (isCached) cache();
			}
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
			if (mX != value) {
				mX = value;
				if (isCached) cache();
			}
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
			if (mY != value) {
				mY = value;
				if (isCached) cache();
			}	
		}
		
    }
}