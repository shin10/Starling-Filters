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
    
    
    /** The EdgesFilter applies a edge detection calculated with the Scharr-Operator
	 *  (a variation of the Sobel Operator) combined with posterization.
	 *  There are several options to achieve different effects, like "glowing edges",
	 *  or comic like results by combining the edge detection with the posterized original.
	 *
	 *  @see http://en.wikipedia.org/wiki/Sobel_operator
	 *  @see starling.filters.FragmentFilter
	 *
	 *  @see http://www.flintfabrik.de
	 *  @author Michael Trenkler
     */
    public class EdgesFilter extends FragmentFilter
    {
		private static const LUMA_R:Number = 0.299;
        private static const LUMA_G:Number = 0.587;
        private static const LUMA_B:Number = 0.114;
		
        private var mColorsOfOriginal:int = 255;
		private var mGrayscale:Boolean = true;
		private var mInverted:Boolean = false;
        private var mShaderProgram:Program3D;
        private var mShaderVars:Vector.<Number> = new <Number>[0,0,0,0,0,0,0,0,0,0,0,0];;
		private var mShowOriginal:Boolean = false;
		private var mStrength:Number = 1;
        private var mThreshold:Number = 0;
		
        /** Creates a new EdgesFilter instance with the specified options. 
         *  @param strength: Strength of calculated lines.
		 *  @default 1
		 * 
		 *  @param threshold: Lower threshold of the edge detection.
		 *  @default 0
		 *
		 *  @param grayscale: Reducing the lines colors to grayscale.
		 *  @default true
		 * 
		 *  @param inverted: Inverts the colors of the edges.
		 *  @default false
		 * 
		 *  @param showOriginal: Whether (posterized) originial should be visible.
		 *  @default false
		 * 
		 *  @param colorsOfOriginal: The posterization's number of colors. 
		 *  @default 255 means no posterization.
		 * 
		 * 
         */
        public function EdgesFilter(strength:Number = 1, threshold:Number = 0, grayscale:Boolean = true, inverted:Boolean = false, showOriginal:Boolean = false, colorsOfOriginal:int = 255, resolution:Number=1)
        {
			this.strength = strength;
			this.threshold = threshold;
			this.grayscale = grayscale
			this.inverted = inverted;
			this.showOriginal = showOriginal;
			this.numColors = colorsOfOriginal;
			
			super(1, resolution);
        }
		
		/** @private */
        protected override function activate(pass:int, context:Context3D, texture:Texture):void
        {							
			mShaderVars = new <Number> [
								1 / texture.nativeWidth,	// horizontal pixel distance
								1 / texture.nativeHeight,	// vertical pixel distance
								1,	// moving / setting alpha
								0,	// not moving
			
								3,	// Scharr operator 
								10, // Scharr operator 
								mStrength/9,	// 3x3 matrix folding
								mThreshold,		// threshold
			
								mColorsOfOriginal,	// posterization
								0.6,	// gamma
								1/0.6,	// rcp gamma
								0,
								
								//grayscale
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
			
				"mov ft7, v0  \n" + // top
				"sub ft7.y, v0.y, fc0.y  \n" + // top
				"tex ft0, ft7, fs0<2d, clamp, linear, mipnone>  \n" +
				"sub ft7.x, ft7.x, fc0.x  \n" + // top left
				"tex ft1, ft7, fs0<2d, clamp, linear, mipnone>  \n" +
				"add ft7.y, ft7.y, fc0.y  \n" + // left
				"tex ft2, ft7, fs0<2d, clamp, linear, mipnone>  \n" +
				"add ft7.y, ft7.y, fc0.y  \n" + // bottom left
				"tex ft3, ft7, fs0<2d, clamp, linear, mipnone>  \n" +
				"add ft7.x, ft7.x, fc0.x  \n" + // bottom
				"tex ft4, ft7, fs0<2d, clamp, linear, mipnone>  \n" +
				"add ft7.x, ft7.x, fc0.x  \n" + // bottom right
				"tex ft5, ft7, fs0<2d, clamp, linear, mipnone>  \n" +
				"sub ft7.y, ft7.y, fc0.y  \n" + // right
				"tex ft6, ft7, fs0<2d, clamp, linear, mipnone>  \n" +
				
				//Gx
				"sub ft2.xyz, ft2.xyz, ft6.xyz	\n" +
				"mul ft2.xyz, ft2.xyz, fc1.yyy	\n" +
				
				"sub ft6.xyzw, ft7.xyzy, fc0.wyww	\n" + // top right
				"tex ft7, ft6, fs0<2d, clamp, linear, mipnone>  \n" +
				
				"sub ft6.xyz, ft1.xyz, ft7.xyz  \n" +
				"add ft6.xyz, ft6.xyz, ft3.xyz  \n" +
				"sub ft6.xyz, ft6.xyz, ft5.xyz  \n" +
				"mul ft6.xyz, ft6.xyz, fc1.xxx  \n" +
				
				"add ft2.xyz, ft2.xyz, ft6.xyz  \n" +
				
				//Gy
				"sub ft0.xyz, ft0.xyz, ft4.xyz  \n" +
				"mul ft0.xyz, ft0.xyz, fc1.yyy  \n" +
				
				"sub ft1.xyz, ft1.xyz, ft3.xyz  \n" +
				"add ft1.xyz, ft1.xyz, ft7.xyz  \n" +
				"sub ft1.xyz, ft1.xyz, ft5.xyz  \n" +
				"mul ft1.xyz, ft1.xyz, fc1.xxx  \n" +
				
				"add ft0.xyz, ft0.xyz, ft1.xyz  \n" +
				
				//G
				"mul ft2.xyz, ft2.xyz, ft2.xyz  \n" +
				"mul ft0.xyz, ft0.xyz, ft0.xyz  \n" +
				"add ft0.xyz, ft0.xyz, ft2.xyz  \n" +
				"sqt ft0.xyz, ft0.xyz  \n" +
				
				"mul ft0.xyz, ft0.xyz, fc1.zzz  \n";
				
				
				
			//grayscale
			if (mGrayscale) {
				fragmentProgramCode += 	
					"mul ft0, ft0, fc3			\n" +
					"add ft0.x, ft0.x, ft0.y	\n" +
					"add ft0.x, ft0.x, ft0.z	\n" +
					"mov ft0.yz, ft0.xx			\n";
			}
			
			fragmentProgramCode +=
				//threshold
				"sub ft0.xyz, ft0.xyz, fc1.www	\n" +
				"sat ft0.xyz, ft0.xyz			\n" +
				"tex ft1, v0, fs0<2d, clamp, linear, mipnone>  \n";
					
			if (mShowOriginal) {
				fragmentProgramCode +=
					"pow ft1.xyz, ft1.xyz, fc2.yyy	\n" +
					"mul ft1.xyz, ft1.xyz, fc2.xxx	\n" +
					"frc ft2.xyz, ft1.xyz			\n" +
					"sub ft1.xyz, ft1.xyz, ft2.xyz	\n" +
					"div ft1.xyz, ft1.xyz, fc2.xxx	\n" +
					"pow ft1.xyz, ft1.xyz, fc2.zzz	\n" +
				
				(mInverted ? "sub" : "add") + " ft0.xyz, ft1.xyz, ft0.xyz	\n";
				
			}else {
				if (mInverted) {
					fragmentProgramCode +=	
						"neg ft0.xyz ft0.xyz			\n" +
						"add ft0.xyz ft0.xyz, fc0.zzz	\n";
				}
			}
			
			fragmentProgramCode +=
				"mov ft0.w, ft1.w	\n" +
				"mov oc, ft0		\n";
				
            
            mShaderProgram = assembleAgal(fragmentProgramCode);
        }
		
		/** @inheritDoc */
        public override function dispose():void
        {
            if (mShaderProgram) mShaderProgram.dispose();
            super.dispose();
        }
        
		
		
		/**
		 * Sets the color of the edges to grayscale.
		 */
		public function get grayscale():Boolean {
			return mGrayscale;	
		}
		
		public function set grayscale(value:Boolean):void {
			mGrayscale = value;
			createPrograms();
		}
		
		/**
		 * Inverts the color of the edges.
		 */
		public function get inverted():Boolean {
			return mInverted;	
		}
		
		public function set inverted(value:Boolean):void {
			mInverted = value;
			createPrograms();
		}
		
		/**
		 * Number of colors of the original, posterizing the original.
		 */
		public function get numColors():int {
			return mColorsOfOriginal;	
		}
		
		public function set numColors(value:int):void {
			mColorsOfOriginal = Math.max(0, Math.min(value, 255));
			trace(mColorsOfOriginal);
		}
		
		/**
		 * Shows the (posterized) source, if set to true.
		 */
		public function get showOriginal():Boolean {
			return mShowOriginal;	
		}
		
		public function set showOriginal(value:Boolean):void {
			mShowOriginal = value;
			createPrograms();
		}
		
		/**
		 * Strength of calculated lines.
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
		 * Lower threshold of the edge detection.
		 */
		public function get threshold():Number 
		{
			return mThreshold;
		}
		
		public function set threshold(value:Number):void 
		{
			mThreshold = Math.max(0,Math.min(value, 1));
		}
    }
}