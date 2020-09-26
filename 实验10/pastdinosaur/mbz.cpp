/*void C退火View::OnDraw(CDC *pDC*);
{
    C退火Doc *pDoc = GetDocument();
    ASSERT_VALID(pDoc);
    if (!pDoc)
        return;
        // TODO: 在此处为本机数据添加绘制代码
*/ 
#include "math.h"
#define Pi 3.14159

    {
        //C退火Doc *pDoc = GetDocument();
        ASSERT_VALID(pDoc);
        //绘制画笔
        CPen cpen, pen;
        cpen.CreatePen(PS_SOLID, 4, RGB(0, 0, 0));
        pen.CreatePen(PS_SOLID, 2, RGB(255, 0, 0));
        pDC->SelectObject(&cpen);

        //指定原点
        pDC->SetViewportOrg(300, 300);
        pDC->SetTextColor(RGB(255, 0, 0));
        double nTemp int n
            //绘制横坐标
            CString sPiText[] = {"-1/2π", "1/2π", "π", "3/2π", "2π", "5/2π", "3π", "7/2π", "4π", "9/2π", "5π"};
        for (int n = -1, nTemp = 0; nTemp <= 660; n++, nTemp += 60)
        {
            pDC->LineTo(60 * n, 0); //坐标横线
            pDC->LineTo(60 * n, -5);
            pDC->MoveTo(60 * n, 0);
            pDC->TextOut(60 * n - sPiText[n + 1].GetLength() * 3, 16, sPiText[n + 1]);
        }
        pDC->MoveTo(0, 0);
        CString sTemp;
        //绘制纵坐标
        for (n = -4, nTemp = 0; nTemp <= 180; n++, nTemp = 60 * n)
        {
            pDC->LineTo(0, 60 * n);
            pDC->LineTo(5, 60 * n);
            pDC->MoveTo(0, 60 * n);
            sTemp.Format("%d", -n);
            pDC->TextOut(10, 60 * n, sTemp);
        }
        double y, radian;
        pDC->SelectObject(&pen);

        //绘制相关曲线
        for (int x = -60; x < 600; x++)
        {
            //弧度=X坐标/曲线宽度*角度*π
            //Y坐标=振幅*曲线宽度*sin(弧度)
            radian = x / ((double)60 * 2) * Pi;
            y = sin(radian) * 2 * 60;
            pDC->MoveTo((int)x, -(int)y);
            pDC->LineTo((int)x, -(int)y);
        }
        cpen.DeleteObject();
        pen.DeleteObject();
    }
//}
