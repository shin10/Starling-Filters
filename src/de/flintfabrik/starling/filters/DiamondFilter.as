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
	
    
	/**
	 * Pixelates DisplayObjects to diamond/hex like shapes.
	 * 
	 * @author Michel Trenkler
	 */
	
    public class DiamondFilter extends FragmentFilter
    {
		
		private static var fragment_shader:String = "";
		private var mCutAngle:Number = 0;
		private var mCutAngleConTan:Number = 0;
		private var mCutWidth:Number = 0;
		private var mFlat:Boolean = true;
		private var mObjectHeight:Number = 0;
		private var mObjectWidth:Number = 0;
		private var mPaneRatio:Number = 1;
		private var mPanes:Number;
		private var mShaderProgram:Program3D;
		private var mShaderVars:Vector.<Number> = new <Number>[0,0,0,0, 0,0,0,0, 0,0,0,0];
		/**
		 * Creates a new Instance of the DiamondFilter
		 * 
		 * @param	panes: Number of panes along the x-axis
		 * @default 20
		 * 
		 * @param	flat: Whether planes are monochrome or ... "ugly" (not sure where I'm going here).
		 * @default true
		 */
        public function DiamondFilter(panes:Number = 20, flat:Boolean = true, resolution:Number=1)
        {
            this.panes = panes;
			mFlat = flat
			hex();
			super(1, resolution);
        }
		
		 /** @private */
        protected override function activate(pass:int, context:Context3D, texture:Texture):void
        {
			mShaderVars = new <Number> [
					mPanes,
					mPanes / mPaneRatio * (texture.height / texture.width),
					mPaneRatio * mCutAngleConTan,
					mCutWidth * 0.5,
					
					0, // not used  
					Math.PI,  // Math.PI
					0,  // compare with zero
					0.5, // coord movment
					
					(1/texture.width),
					(1/texture.height),
					(mObjectWidth/texture.width) - (1/texture.width),
					(mObjectHeight/texture.height) - (1/texture.height)
				];

			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, mShaderVars, 3);
            context.setProgram(mShaderProgram);
        }
		
		  /** @private */
        protected override function createPrograms():void
        {
			if (mShaderProgram) mShaderProgram.dispose();
			
			fragment_shader =
			"mul ft0.xy,  v0.xy, fc0.xy		\n" + // * size
			"frc ft1.xy, ft0.xy				\n" + // = rest
			"sub ft2.xy, ft0.xy, ft1.xy		\n" + // = rounded position
			"sub ft3.xy, ft1.xy, fc1.ww		\n" + // rest - 0.5
			"abs ft4.xy, ft3.xy				\n" + // abstand zu pivot
			"sge ft5.xy, ft3.xy, fc1.zz		\n" + // rest.xy >= 0 ? (negative coords?)
				"sub ft6.xy, ft5.xy, fc1.ww		\n" + // * -0.5 : 0.5 
			"mul ft4.y, ft4.y, fc0.z		\n" + //
			"add ft4.y, ft4.y, fc0.w		\n" + //
			"sge ft5.xy, ft4.xy, ft4.yx		\n" + // abstand.x < abstand.y ?
				"mul ft6.xy, ft6.xy, ft5.xy		\n" + // * +/-0.5 : 0 (offset)
			"add ft7.xy, ft2.xy, ft6.xy		\n";  // gerundet + verschiebung
			
			///////experimental
			if (!mFlat) {
				fragment_shader +=	
				"sub ft0.xy, ft7.xy, ft0.xy		\n" +
				"add ft0.xy, ft0.xy, fc1.ww		\n" +
					"mul ft0.xy, ft0.xy, fc1.yy		\n" + // * PI
					"cos ft0.xy, ft0.xy				\n" +
					"mul ft0.xy, ft0.xy, fc1.ww		\n" + // *0.5
				"sub ft0.xy, ft0.xy, fc1.ww		\n" +
				"add ft7.xy, ft7.xy, ft0.xy		\n";
			}
			/////////
			
			fragment_shader +=
				"add ft7.xy, ft7.xy, fc1.ww		\n" + // + 0.5
				"div ft7.xy, ft7.xy, fc0.xy		\n" + // texture position
			
				// avoid empty texture parts
				"max ft7.xy, ft7.xy, fc2.xy		\n" +
				"min ft7.xy, ft7.xy, fc2.zw		\n" +
			
				"tex oc, ft7.xy, fs0<2d, clamp, linear, mipnone>  \n";
            mShaderProgram = assembleAgal(fragment_shader);
        }
       
		/**
		 * Sets properties for diamond shaped panes
		 */
		public function diamonds():void {
			paneRatio = 1;
			cutAngle = 45;
			cutWidth = 0;
		}
		
         /** @private */
        public override function dispose():void
        {
            if (mShaderProgram) mShaderProgram.dispose();
            super.dispose();
        }
		
		/**
		 * Sets properties for hex shaped panes
		 */
		public function hex():void {
			paneRatio = (2/3)* Math.sqrt(0.75);
			cutAngle = 60;
			cutWidth = 1 / 3;
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
		 * Angle of cut between the two pane types.
		 */
		public function set cutAngle(value:Number):void {
			mCutAngle = value;
			mCutAngleConTan = Math.cos( Math.PI * (mCutAngle / 180) ) / Math.sin( Math.PI * (mCutAngle / 180) );
		}
		public function get cutAngle():Number {
			return mCutAngle;
		}
		
		/**
		 * Width of cut between the two pane types.
		 */
		public function set cutWidth(value:Number):void {
			mCutWidth = value;
		}
		public function get cutWidth():Number {
			return mCutWidth;
		}
		
		/**
		 * Ratio between the two pane types.
		 */
		public function set paneRatio(value:Number):void {
			mPaneRatio = value;
		}
		public function get paneRatio():Number {
			return mPaneRatio;
		}
		
		/**
		 * Number of panes along the x-axes.
		 */
		public function set panes(value:Number):void {
			mPanes = value;
		}
		public function get panes():Number {
			return mPanes;
		}
		
    }
}