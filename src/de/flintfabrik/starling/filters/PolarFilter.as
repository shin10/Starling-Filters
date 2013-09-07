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
    
    /** The PolarFilter class maps the Image around the center 
	 *  
	 *  @see starling.filters.FragmentFilter
	 *
	 *  @see http://www.flintfabrik.de
	 *  @author Michael Trenkler
     */
    public class PolarFilter extends FragmentFilter
    {
		private var mObjectHeight:Number = 0;
		private var mObjectWidth:Number = 0;
		private var mRadius1:Number = 0;
		private var mRadius2:Number = 0.5;
		private var mRotation:Number = Math.PI * .5;
        private var mShaderProgram:Program3D;
        private var mShaderVars:Vector.<Number>;
		private var mX:Number = 0.5;
		private var mY:Number = 0.5;
		
        /** Creates a new WhirlFilter instance with the specified arguments. 
         *  @param innerRadius: Values greater 0 result in a "donut"
		 *  @param outerRadius: the overall radius of the effect
		 * 
         */
        public function PolarFilter(innerRadius:Number=0.25, outerRadius:Number=0.5, resolution:Number=1)
        {
			this.radius1 = innerRadius;
			this.mRadius2 = outerRadius;
			super(1, resolution);
        }
		
		/** @private */
        protected override function activate(pass:int, context:Context3D, texture:Texture):void
        {
			mShaderVars = new <Number> [
				mX /* center x (u) */,
				mY /* center y (v) */,
				mRotation,
				2*Math.PI,
				
				2.220446049250313e-16, 0.7853981634, 0.1821, 0.9675 /* atan2 magic numbers */,
				
				mRadius1,
				mRadius2-mRadius1,
				1,
				0,
				
				// aspect ratios
				texture.width/mObjectWidth,
				texture.height/mObjectHeight,
				mObjectWidth/mObjectHeight,
				0
			];
			
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, mShaderVars);
            context.setProgram(mShaderProgram);
        }
        
        /** @private */
        protected override function createPrograms():void
        {
			if (mShaderProgram) mShaderProgram.dispose();
			
			var fragmentProgramCode:String =
				"mul ft0.xyzw, v0.xyzw, fc3.xyww	\n" +
				
				"sub ft0.xy, ft0.xy, fc0.xy			\n" + // - center
				"mul ft0.x, ft0.x, fc3.z			\n" + // aspect ratio
				
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
				"mov ft4, v0					\n" + 
				"sub ft4.x, ft1.x, fc2.x		\n" + // inner radius
				"div ft4.x, ft4.x, fc2.y		\n" + // outer radius
				"mov ft4.y, ft3.x				\n" +
				"add ft4.y, ft4.y, fc0.z		\n" + // add rotation
				"add ft4.y, ft4.y, fc0.w		\n" + // + 2*PI (calculate positive equivalent of values)
				"div ft4.y, ft4.y, fc0.w		\n" + // / 2*PI
				"frc ft4.y, ft4.y 				\n" + // fractional part
				
				// clamp inner
				"sge ft4.w, ft4.x, fc2.w		\n" + 
				"mul ft4.xyz, ft4.xyz, ft4.www	\n" +
				
				// clamp outer
				"slt ft4.w, ft4.x, fc2.z		\n" + 
				"mul ft4.xyz, ft4.xyz, ft4.www  \n" +
				
				"div ft4.xy, ft4.xy, fc3.yx		\n" + // aspect ratios
				"tex oc, ft4.yx, fs0<2d, clamp, linear, mipnone>	\n";
				
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
		 * The inner radius of the effect.
		 */
		public function get radius1():Number 
		{
			return mRadius1;
		}
		
		public function set radius1(value:Number):void 
		{
			mRadius1 = Math.max(0, Math.min(value, 1));
		}
		
		/**
		 * The outer radius of the effect.
		 */
		public function get radius2():Number 
		{
			return mRadius2;
		}
		
		public function set radius2(value:Number):void 
		{
			mRadius2 = Math.max(0, Math.min(value, 1));
		}
		
		/**
		 * Rotation in radians (0 to 2*PI)
		 */
		public function get rotation():Number 
		{
			return mRotation;
		}
		
		public function set rotation(value:Number):void 
		{
			mRotation = Math.max(0, Math.min(value, Math.PI*2));
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