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
	import starling.filters.FragmentFilter;
	import starling.textures.Texture;
        
    /** The EmbossFilter creates a simple relief like effect, known from image processing programs.
	 *
	 *  @see starling.filters.FragmentFilter
	 *
	 *  @see http://www.flintfabrik.de
	 *  @author Michael Trenkler
     */
    public class EmbossFilter extends FragmentFilter
    {
		private static const LUMA_R:Number = 0.299;
        private static const LUMA_G:Number = 0.587;
        private static const LUMA_B:Number = 0.114;
		
        private var mAngle:Number = 0;
        private var mShaderProgram:Program3D;
		private var mShaderVars:Vector.<Number> = new <Number>[0,0,0,0, 0,0,0,0, 0,0,0,0];
		private var mShowOriginal:Boolean = false;
		private var mStrength:Number = 1;
        private var mThreshold:Number = 0;
		
        /** Creates a new EmbossFilter instance with the specified options. 
         *  @param strength: Strength of the relief effect.
		 *  @param angle: Direction of the light source in degrees.
		 *  @param threshold: set the lower threshold to ignore slightly changes of the source
         *  @param showOriginal: whether the source should still be visible.
         */
        public function EmbossFilter(strength:Number = 1, angle:Number = 135, threshold:Number = 0, showOriginal:Boolean = false, resolution:Number=1)
        {
			this.strength = strength;
			this.threshold = threshold;
			this.showOriginal = showOriginal;
			this.angle = angle;
			super(1, resolution);
        }
		
        // ??? are those results better? I guess so ... TODO
		
        /** @private */
        protected override function activate(pass:int, context:Context3D, texture:Texture):void
        {
			mShaderVars = new <Number> [
								Math.SQRT2*Math.cos(mAngle) / texture.nativeWidth,	// horizontal texel distance
								Math.SQRT2*Math.sin(mAngle) / texture.nativeHeight,	// vertical texel distance
								1,	// moving / setting alpha
								0,	// not moving
			
								0, // not used
								0.5,
								mStrength, // folding
								mThreshold, // threshold
								
								// grayscale
								LUMA_R,
								LUMA_G,
								LUMA_B,
								1
							];
			
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, mShaderVars);
            context.setProgram(mShaderProgram);
        }
        
        /** @private */
        protected override function createPrograms():void
        {
			if (mShaderProgram) mShaderProgram.dispose();
			
            var fragmentProgramCode:String =
			
				"mov ft0, v0										\n" +
				
				//relief
				"sub ft1.xy, v0.xy, fc0.xy							\n" +
				"tex ft1, ft1.xy, fs0<2d, clamp, linear, mipnone>	\n" +
				"add ft2.xy, v0.xy, fc0.xy							\n" +
				"tex ft2, ft2.xy, fs0<2d, clamp, linear, mipnone>	\n" +
				"mov ft3, v0										\n" +
				"sub ft3.xyz, ft1.xyz, ft2.xyz						\n" +
				
				//grayscale
				"mul ft3,   ft3,   fc3		\n" + // Luma
				"add ft3.x, ft3.x, ft3.y	\n" +
				"add ft3.x, ft3.x, ft3.z	\n" +
				
					//threshold
					"sub ft4.x, ft3.x, fc1.w	\n" +
					"sat ft4.y, ft4.x			\n" +
					
					"add ft4.x, ft3.x, fc1.w	\n" +
					"neg ft4.x, ft4.x			\n" +
					"sat ft4.x, ft4.x			\n" +
					"sub ft4.x, ft4.y, ft4.x	\n" +
					"mov ft3.xyz, ft4.xxx		\n" +
					
				// relief strength
				"mul ft3.xyz, ft3.xyz, fc1.zzz					\n" +
				"tex ft4, v0, fs0<2d, clamp, linear, mipnone>	\n";
				
				if(mShowOriginal) {
					fragmentProgramCode += 
					"add ft4.xyz, ft4.xyz, ft3.xyz	\n" + 
					"mov oc, ft4					\n";
				} else {
					fragmentProgramCode += 
					"add ft3.xyz, ft3.xyz, fc1.yyy	\n" + 
					"mov ft3.w, ft4.w				\n" + // set texture alpha to 1
					"mov oc, ft3					\n";
				}
				
            mShaderProgram = assembleAgal(fragmentProgramCode);
        }
        
		/** @inheritDoc */
        public override function dispose():void
        {
            if (mShaderProgram) mShaderProgram.dispose();
            super.dispose();
        }
		
		/**
		 * Direction of the light source in degrees.
		 */
		public function get angle():Number {
			return (mAngle * 180) / Math.PI;
		}
		
		public function set angle(value:Number):void {
			mAngle = (value / 180) * Math.PI;
		}
		
		/**
		 * Show the relief effect in gray or applied on the original
		 */
		public function get showOriginal():Boolean {
			return mShowOriginal;	
		}
		
		public function set showOriginal(value:Boolean):void {
			mShowOriginal = value;
			createPrograms();
		}
		
		/**
		 * Strength of the relief effect.
		 */
		public function get strength():Number 
		{
			return mStrength;
		}
		
		public function set strength(value:Number):void 
		{
			mStrength = Math.max(0, value);
		}
		
		/**
		 * The lower threshold, ignoring slightly changes of the source
		 */
		public function get threshold():Number 
		{
			return mThreshold;
		}
		
		public function set threshold(value:Number):void 
		{
			mThreshold = Math.max(0, Math.min(value, 1));
		}
		
    }
}