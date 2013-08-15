//
//  BRM_OpenGLView.m
//  brainmapper
//
//  Created by Veena Krish on 7/23/13.
//  Copyright (c) 2013 University of Pennsylvania. All rights reserved.
//

#import "BRM_OpenGLView.h"
#include <OpenGL/OpenGL.h>

@implementation BRM_OpenGLView

static void drawAnObject ()
{
    glColor3f(1.0f, 0.85f, 0.35f);
    glBegin(GL_TRIANGLES);
    {
        glVertex3f(  0.0,  0.6, 0.0);
        glVertex3f( -0.2, -0.3, 0.0);
        glVertex3f(  0.2, -0.3 ,0.0);
    }
    glEnd();
}

-(void) drawRect: (NSRect) bounds
{
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    drawAnObject();
    glFlush();
}

@end



