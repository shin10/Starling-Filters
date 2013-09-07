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
    
    
    /** The WhirlFilter class applies a smiple whirl effect commonly knwon from 
	 *  screensavers and similar stuff. The whirl can be applied within and/or
	 *  outside of the given radius.
	 *
	 *  @see starling.filters.FragmentFilter
	 *
	 *  @see http://www.flintfabrik.de
	 *  @author Michael Trenkler
     */
    public class WhirlFilter extends FragmentFilter
    {
		private var mAmount:Number = 1;
        private var mInside:Boolean = true;
		private var mObjectHeight:Number = 0;
		private var mObjectWidth:Number = 0;
		private var mOutside:Boolean = false;
		private var mRadius:Number = 0.5;
        private var mShaderProgram:Program3D;
        private var mShaderVars:Vector.<Number> = new <Number>[0, 0, 0, 0, 0, 0, 0, 0];
		private var mX:Number = 0.5;
		private var mY:Number = 0.5;
		
        /** Creates a new WhirlFilter instance with the specified arguments. 
         *  @param inside: whether the effect is applied inside of the radius.
		 *  @default true
		 *  @param outside: whetherthe effect is applied outside of the radius. 
		 *  @default false
         */
        public function WhirlFilter(inside:Boolean = true, outside:Boolean = false, resolution:Number=1)
        {
			mInside = inside;
			mOutside = outside;
			super(1, resolution);
        }
		
		/** @private */
        protected override function activate(pass:int, context:Context3D, texture:Texture):void
        {
			
			mShaderVars = new <Number> [
				mX /* center x (u) */,
				mY /* center y (v) */,
				Math.PI,
				2 * Math.PI,
				
				2.220446049250313e-16, 0.7853981634, 0.1821, 0.9675 /* atan2 magic numbers */,
				
				mRadius,
				mAmount * 8.2,
				0,
				0,
				
				mObjectWidth/texture.width,
				mObjectHeight/texture.height,
				mObjectWidth/mObjectHeight,
				1
			  ];
			
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, mShaderVars);
            context.setProgram(mShaderProgram);
        }
		
        /** @private */
        protected override function createPrograms():void
        {
			if (mShaderProgram) mShaderProgram.dispose();
			
			if (mInside || mOutside) {
				var fragmentProgramCode:String =
				"div ft0.xyzw, v0.xyzw, fc3.xyww	\n" +
				"sub ft0.xy, ft0.xy, fc0.xy			\n" + // - center
				"mul ft0.x, ft0.x, fc3.z			\n" + // aspect ratio
				
				"sub ft0.zw, ft0.zw, ft0.zw			\n" +
				
				// distance to center
				"dp3 ft1, ft0, ft0					\n" +
				"sqt ft1, ft1						\n" +
				
				/* In their eternal wisdom Adobe or whoever is responsible
				 * made no atan2 in AGAL, so we need to use approximation,
				 * for example the one by Eugene Zatepyakin, Joa Ebert and
				 * Patrick Le Clec'h http://wonderfl.net/c/1HbR/read */
				
				"abs ft2, ft0\n" /* ft2 = |x|, |y| */ +
				/* sge, because dated AGALMiniAssembler does not have seq */
				"sge ft2, ft0, ft2\n" /* ft2.zw are both =1 now, since ft0.zw were =0 */ +
				"add ft2.xyw, ft2.xyw, ft2.xyw\n" +
				"sub ft2.xy, ft2.xy, ft2.zz\n" /* ft2 = sgn(x), sgn(y), 1, 2 */ +
				"sub ft2.w, ft2.w, ft2.x\n" /* ft2.w = "(partSignX + 1.0)" = 2 - sgn(x) */ +
				"mul ft2.w, ft2.w, fc1.y\n" /* ft2.w = "(partSignX + 1.0) * 0.7853981634" */ +
				"mul ft2.z, ft2.y, ft0.y\n" /* ft2.z = "y * sign" */ +
				"add ft2.z, ft2.z, fc1.x\n" /* ft2.z = "y * sign + 2.220446049250313e-16" or "absYandR" initial value */ +
				"mul ft3.x, ft2.x, ft2.z\n" /* ft3.x = "signX * absYandR" */ +
				"sub ft3.x, ft0.x, ft3.x\n" /* ft3.x = "(x - signX * absYandR)" */ +
				"mul ft3.y, ft2.x, ft0.x\n" /* ft3.y = "signX * x" */ +
				"add ft3.y, ft3.y, ft2.z\n" /* ft3.y = "(signX * x + absYandR)" */ +
				"div ft2.z, ft3.x, ft3.y\n" /* ft2.z = "(x - signX * absYandR) / (signX * x + absYandR)" or "absYandR" final value */ +
				"mul ft3.x, ft2.z, ft2.z\n" /* ft3.x = "absYandR * absYandR" */ +
				"mul ft3.x, ft3.x, fc1.z\n" /* ft3.x = "0.1821 * absYandR * absYandR" */ +
				"sub ft3.x, ft3.x, fc1.w\n" /* ft3.x = "(0.1821 * absYandR * absYandR - 0.9675)" */ +
				"mul ft3.x, ft3.x, ft2.z\n" /* ft3.x = "(0.1821 * absYandR * absYandR - 0.9675) * absYandR" */ +
				"add ft3.x, ft3.x, ft2.w\n" /* ft3.x = "(partSignX + 1.0) * 0.7853981634 + (0.1821 * absYandR * absYandR - 0.9675) * absYandR" */ +
				"mul ft3.x, ft3.x, ft2.y\n" /* ft3.x = "((partSignX + 1.0) * 0.7853981634 + (0.1821 * absYandR * absYandR - 0.9675) * absYandR) * sign" */ +
				
				//remap
				"mov ft7, v0				\n" + 
				"sub ft7.z, fc2.x, ft1.w	\n" + //percent
				"div ft7.z, ft7.z, fc2.x	\n" +
				
				"mul ft7.z, ft7.z, ft7.z	\n" + // theta
				"mul ft7.z, ft7.z, fc2.y	\n" + // amount
				"add ft7.z, ft7.z, ft3.x	\n" +
				
				"cos ft7.x, ft7.z			\n" +
				"sin ft7.y, ft7.z			\n" +
				"mul ft7.xy, ft7.xy, ft1.zz	\n";
				
				if(!mInside || !mOutside){
					if (mInside) {
						fragmentProgramCode +=
						"slt ft6.w ft1.w, fc2.x			\n" + // effect border
						//inner
						"div ft7.x, ft7.x, fc3.z		\n" + // aspect ratio
						"add ft7.xy, ft7.xy, fc0.xy		\n" + // + center
						"mul ft7.xy, ft7.xy, ft6.ww		\n" +
						"mul ft7.xy, ft7.xy, fc3.xy		\n" + // texture ratios
						//outer
						"sge ft6.w ft1.w, fc2.x			\n" +
						"mul ft6.xy, v0.xy, ft6.ww		\n" +
						//combine
						"add ft7.xy, ft6.xy, ft7.xy		\n";
					}
					if (mOutside) {
						
						fragmentProgramCode +=
						"sge ft6.w ft1.w, fc2.x			\n" + // effect border
						//outer
						"div ft7.x, ft7.x, fc3.z		\n" + // aspect ratio
						"add ft7.xy, ft7.xy, fc0.xy		\n" + // + center
						"mul ft7.xy, ft7.xy, ft6.ww		\n" +
						"mul ft7.xy, ft7.xy, fc3.xy		\n" + // texture ratios
						//inner
						"slt ft6.w ft1.w, fc2.x			\n" +
						"mul ft6.xy, v0.xy, ft6.ww		\n" +
						//combine
						"add ft7.xy, ft6.xy, ft7.xy		\n";
					}
				}else {
					fragmentProgramCode +=
						"div ft7.x, ft7.x, fc3.z		\n" + // aspect ratio
						"add ft7.xy, ft7.xy, fc0.xy		\n" + // + center
						"mul ft7.xy, ft7.xy, fc3.xy		\n";  // texture ratios
				}
				
				fragmentProgramCode +=
					// clamp the visible rect
					"max ft7.xy, ft7.xy, fc2.ww		\n" +
					"min ft7.xy, ft7.xy, fc3.xy		\n" +
					"tex oc, ft7.xy, fs0<2d, clamp, linear, mipnone>	\n";
			}else {
				fragmentProgramCode =
					"tex oc, v0, fs0<2d, clamp, linear, mipnone>	\n";
			}
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
			mAmount = value;
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
			mRadius = Math.max(0, Math.min(value, 255));
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